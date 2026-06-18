import Foundation

public actor PulseEngine {
    public typealias AlertHandler = @Sendable (ProductionSnapshot, String) async -> Void

    private let config: ProductionConfig
    private let credentialsStore: CredentialsStore
    private let healthProber: HealthProber
    private let privateProber: PrivateNetworkProber
    private let tailscale: TailscaleReachability
    private let coolifyClientFactory: @Sendable (URL, String) -> any CoolifyClient
    private let hetznerClientFactory: @Sendable (String) -> any HetznerClient
    private let telegram: TelegramNotifier
    private var debouncer: AlertDebouncer
    private let onAlert: AlertHandler?

    private var cache = PulseSourceCache()
    private(set) public var resolvedServers: [ResolvedServer] = []
    private(set) public var latestSnapshot: ProductionSnapshot?
    private(set) public var operatorHints = OperatorHints.none

    public init(
        config: ProductionConfig,
        credentialsStore: CredentialsStore,
        tailscale: TailscaleReachability = StubTailscaleReachability(connected: false),
        healthProber: HealthProber = HealthProber(),
        privateProber: PrivateNetworkProber = PrivateNetworkProber(),
        coolifyClientFactory: @escaping @Sendable (URL, String) -> any CoolifyClient = { LiveCoolifyClient(baseURL: $0, token: $1) },
        hetznerClientFactory: @escaping @Sendable (String) -> any HetznerClient = { LiveHetznerClient(token: $0) },
        telegram: TelegramNotifier = TelegramNotifier(),
        onAlert: AlertHandler? = nil
    ) {
        self.config = config
        self.credentialsStore = credentialsStore
        self.tailscale = tailscale
        self.healthProber = healthProber
        self.privateProber = privateProber
        self.coolifyClientFactory = coolifyClientFactory
        self.hetznerClientFactory = hetznerClientFactory
        self.telegram = telegram
        self.debouncer = AlertDebouncer(config: config.alerts)
        self.onAlert = onAlert
    }

    public func acknowledgeAlerts(for duration: TimeInterval, from now: Date = Date()) {
        debouncer.acknowledge(until: now.addingTimeInterval(duration))
    }

    @discardableResult
    public func refresh(now: Date = Date(), force: Bool = false) async -> ProductionSnapshot {
        let credentials = credentialsStore.load()
        let tailscaleUp = await tailscale.isConnected()
        cache.tailscaleConnected = tailscaleUp

        let dueChannels = channelsDue(now: now, force: force)

        if force || dueChannels.contains(.coolify) {
            await refreshCoolify(credentials: credentials, tailscaleUp: tailscaleUp)
            cache.lastCoolifyRefresh = now
        }
        if force || dueChannels.contains(.hetzner) {
            await refreshHetzner(credentials: credentials)
            cache.lastHetznerRefresh = now
        }
        rebuildResolvedServers()

        if dueChannels.contains(.publicHealth) {
            await refreshPublicHealth()
            cache.lastPublicRefresh = now
        }
        if dueChannels.contains(.privateProbes) {
            await refreshPrivateProbes(tailscaleUp: tailscaleUp)
            cache.lastPrivateRefresh = now
        } else if !tailscaleUp {
            applySkippedPrivateProbes()
        }

        let production = buildSnapshot(now: now)
        latestSnapshot = production
        operatorHints = buildOperatorHints(
            credentials: credentials,
            tailscaleUp: tailscaleUp,
            discoverySummary: config.discovery.enabled
                ? buildDiscoverySummary(snapshotCount: production.servers.count)
                : nil
        )

        let decision = debouncer.evaluate(overall: production.overall, now: now)
        if decision.shouldNotify {
            let message = telegram.formatAlert(snapshot: production)
            if let onAlert {
                await onAlert(production, message)
            } else if config.alerts.telegramEnabled,
                      let bot = credentials.telegramBotToken,
                      let chat = credentials.telegramChatID
            {
                try? await telegram.send(botToken: bot, chatID: chat, text: message)
            }
        }

        return production
    }

    private func channelsDue(now: Date, force: Bool) -> Set<RefreshChannel> {
        var due = Set<RefreshChannel>()
        let polling = config.polling
        if PulseRefreshTiming.isDue(
            lastRefresh: cache.lastPublicRefresh,
            intervalSeconds: polling.publicHealthSeconds,
            now: now,
            force: force
        ) {
            due.insert(.publicHealth)
        }
        if PulseRefreshTiming.isDue(
            lastRefresh: cache.lastCoolifyRefresh,
            intervalSeconds: polling.coolifySeconds,
            now: now,
            force: force
        ) {
            due.insert(.coolify)
        }
        if PulseRefreshTiming.isDue(
            lastRefresh: cache.lastHetznerRefresh,
            intervalSeconds: polling.hetznerSeconds,
            now: now,
            force: force
        ) {
            due.insert(.hetzner)
        }
        if PulseRefreshTiming.isDue(
            lastRefresh: cache.lastPrivateRefresh,
            intervalSeconds: polling.privateProbeSeconds,
            now: now,
            force: force
        ) {
            due.insert(.privateProbes)
        }
        return due
    }

    private func rebuildResolvedServers() {
        resolvedServers = ServerDiscovery.resolve(
            config: config,
            coolifyServers: cache.coolifyServers,
            hetznerHosts: cache.hetznerHosts
        )
    }

    private func refreshPublicHealth() async {
        for server in resolvedServers {
            let configured = server.publicEndpoints
            let discovered = cache.domainsByServerID[server.cacheKey]
                ?? server.coolifyUUID.flatMap { cache.domainsByCoolifyUUID[$0] }
                ?? []
            let endpoints = configured.isEmpty
                ? CoolifyMapper.endpoints(from: discovered)
                : configured
            guard !endpoints.isEmpty else { continue }

            var checks: [EndpointCheckResult] = []
            for endpoint in endpoints {
                checks.append(await healthProber.probe(endpoint: endpoint))
            }
            cache.endpointChecksByServer[server.cacheKey] = checks
        }
    }

    private func refreshCoolify(credentials: PulseCredentials, tailscaleUp: Bool) async {
        guard let base = credentials.coolifyBaseURL,
              let token = credentials.coolifyToken,
              Self.canReachCoolify(baseURL: base, tailscaleUp: tailscaleUp)
        else {
            cache.coolifyServers = []
            cache.containersByServerID = [:]
            cache.containersByCoolifyUUID = [:]
            cache.domainsByServerID = [:]
            cache.domainsByCoolifyUUID = [:]
            return
        }

        let apiBase = config.coolify.apiBaseURL(host: base)
        let client = coolifyClientFactory(apiBase, token)
        let servers = (try? await client.listServers()) ?? []
        cache.coolifyServers = servers

        var resourcesByCoolifyUUID: [String: [CoolifyResource]] = [:]
        var domainsByCoolifyUUID: [String: [String]] = [:]
        for coolify in servers {
            if let resources = try? await client.listResources(serverUUID: coolify.uuid) {
                resourcesByCoolifyUUID[coolify.uuid] = resources
            }
            if let groups = try? await client.listDomains(serverUUID: coolify.uuid) {
                domainsByCoolifyUUID[coolify.uuid] = CoolifyMapper.flattenDomains(groups)
            }
        }

        let supplementalNeeded = servers.contains { resourcesByCoolifyUUID[$0.uuid]?.isEmpty ?? true }
        let applications = supplementalNeeded ? ((try? await client.listApplications()) ?? []) : []
        let services = supplementalNeeded ? ((try? await client.listServices()) ?? []) : []

        var containersByID: [String: [ContainerTile]] = [:]
        var domainsByID: [String: [String]] = [:]
        var containersByUUID: [String: [ContainerTile]] = [:]
        let hosts = ServerDiscovery.resolve(
            config: config,
            coolifyServers: servers,
            hetznerHosts: cache.hetznerHosts
        )
        for server in hosts where server.coolifyManaged {
            guard let uuid = server.coolifyUUID else { continue }
            var resources = CoolifyMapper.mergedResources(
                primaryUUID: uuid,
                serverName: server.name,
                publicIPv4: server.publicIPv4,
                coolifyServers: servers,
                resourcesByUUID: resourcesByCoolifyUUID
            )
            if resources.isEmpty,
               let coolify = servers.first(where: { $0.uuid == uuid }),
               let databaseID = coolify.databaseID
            {
                resources = CoolifyMapper.supplementalResources(
                    databaseID: databaseID,
                    applications: applications,
                    services: services
                )
            }
            let containers = CoolifyMapper.containers(from: resources)
            containersByID[server.cacheKey] = containers
            containersByUUID[uuid] = containers

            var domains = domainsByCoolifyUUID[uuid] ?? []
            for coolify in servers where coolify.uuid != uuid {
                let sameHost = ServerDiscovery.namesMatch(coolify.name, server.name)
                    || (!server.publicIPv4.isEmpty && coolify.ip == server.publicIPv4)
                if sameHost, let aliasDomains = domainsByCoolifyUUID[coolify.uuid] {
                    domains.append(contentsOf: aliasDomains)
                }
            }
            domainsByID[server.cacheKey] = Array(Set(domains)).sorted()
        }
        cache.containersByServerID = containersByID
        cache.containersByCoolifyUUID = containersByUUID
        cache.domainsByServerID = domainsByID
        cache.domainsByCoolifyUUID = domainsByCoolifyUUID
    }

    private func refreshHetzner(credentials: PulseCredentials) async {
        guard let token = credentials.hetznerToken else {
            cache.hetznerHosts = []
            cache.metricsByServerName = [:]
            return
        }
        let client = hetznerClientFactory(token)
        cache.hetznerHosts = (try? await client.listHosts()) ?? []

        var metrics: [String: HetznerServerMetrics] = [:]
        let hosts = ServerDiscovery.resolve(
            config: config,
            coolifyServers: cache.coolifyServers,
            hetznerHosts: cache.hetznerHosts
        )
        for server in hosts {
            guard let hetznerName = server.hetznerServerName else { continue }
            let host = cache.hetznerHosts.first {
                $0.name == hetznerName || ServerDiscovery.namesMatch($0.name, hetznerName)
            }
            guard let host else { continue }
            guard let value = try? await client.metrics(forServerID: host.id) else { continue }
            metrics[host.name] = value
            metrics[hetznerName] = value
            metrics[server.cacheKey] = value
        }
        cache.metricsByServerName = metrics
    }

    private func refreshPrivateProbes(tailscaleUp: Bool) async {
        for server in resolvedServers {
            guard !server.privateProbes.isEmpty else { continue }
            if tailscaleUp {
                var results: [PrivateProbeResult] = []
                for probe in server.privateProbes {
                    results.append(await privateProber.probe(probe))
                }
                cache.privateProbesByServer[server.cacheKey] = results
            } else {
                cache.privateProbesByServer[server.cacheKey] = server.privateProbes.map {
                    PrivateProbeResult(id: $0.id, label: $0.label, status: .skipped, message: "private network")
                }
            }
        }
    }

    private func applySkippedPrivateProbes() {
        for server in resolvedServers where !server.privateProbes.isEmpty {
            cache.privateProbesByServer[server.cacheKey] = server.privateProbes.map {
                PrivateProbeResult(id: $0.id, label: $0.label, status: .skipped, message: "private network")
            }
        }
    }

    private func buildOperatorHints(
        credentials: PulseCredentials,
        tailscaleUp: Bool,
        discoverySummary: String?
    ) -> OperatorHints {
        var messages: [String] = []
        let coolifyNeedsTailscale = credentials.coolifyBaseURL.map { !Self.coolifyReachableWithoutTailscale(baseURL: $0) } ?? false

        if config.discovery.enabled {
            if credentials.coolifyBaseURL == nil || credentials.coolifyToken == nil {
                messages.append("Add Coolify URL + API token — servers are auto-discovered from Coolify")
            } else if resolvedServers.isEmpty {
                messages.append("No servers discovered yet — check Coolify credentials")
            }
        } else {
            messages.append("Static config (\(config.servers.count) servers) — run make setup to enable auto-discovery")
            if credentials.coolifyBaseURL == nil || credentials.coolifyToken == nil {
                messages.append("Add Coolify URL + API token in Settings for container status")
            } else if !tailscaleUp && coolifyNeedsTailscale {
                messages.append("Self-hosted Coolify unreachable — check VPN or URL")
            }
        }

        if credentials.hetznerToken == nil {
            if config.discovery.enabled {
                messages.append("Add Hetzner token + Save — needed for non-Coolify servers (data, search, llm)")
            } else {
                messages.append("Optional: Hetzner token for CPU/RAM and IP enrichment")
            }
        } else if config.discovery.enabled, cache.hetznerHosts.isEmpty {
            messages.append("Hetzner token set but no hosts returned — check token project/permissions")
        }

        return OperatorHints(messages: messages, discoverySummary: discoverySummary)
    }

    private func buildDiscoverySummary(snapshotCount: Int) -> String? {
        let coolifyCount = cache.coolifyServers.count
        let hetznerCount = cache.hetznerHosts.count
        let resolvedCount = resolvedServers.count
        guard coolifyCount > 0 || hetznerCount > 0 || resolvedCount > 0 else { return nil }
        if snapshotCount != resolvedCount {
            return "Showing \(snapshotCount) of \(resolvedCount) — Coolify \(coolifyCount), Hetzner \(hetznerCount)"
        }
        return "Discovered \(resolvedCount) server(s) — Coolify \(coolifyCount), Hetzner \(hetznerCount)"
    }

    /// HTTPS Coolify (e.g. Coolify Cloud) is reachable without Tailscale.
    static func coolifyReachableWithoutTailscale(baseURL: URL) -> Bool {
        baseURL.scheme?.lowercased() == "https"
    }

    static func canReachCoolify(baseURL: URL, tailscaleUp: Bool) -> Bool {
        coolifyReachableWithoutTailscale(baseURL: baseURL) || tailscaleUp
    }

    private func buildSnapshot(now: Date) -> ProductionSnapshot {
        var serverSnapshots: [ServerSnapshot] = []
        var seenIDs = Set<String>()
        for server in resolvedServers {
            guard !seenIDs.contains(server.id) else { continue }
            seenIDs.insert(server.id)
            let serverConfig = server.asServerConfig()
            let endpointChecks = cache.endpointChecksByServer[server.cacheKey] ?? []
            let privateProbes = cache.privateProbesByServer[server.cacheKey] ?? []
            var containers = cache.containersByServerID[server.cacheKey]
                ?? server.coolifyUUID.flatMap { cache.containersByCoolifyUUID[$0] }
                ?? []
            if containers.isEmpty, !server.manualStack.isEmpty {
                containers = CoolifyMapper.manualContainers(
                    from: server.manualStack,
                    endpointChecks: endpointChecks
                )
            }
            let coolifyServer = server.coolifyUUID.flatMap { uuid in
                cache.coolifyServers.first(where: { $0.uuid == uuid })
            }
            let coolifyReachable = coolifyServer?.isReachable
            let coolifyUsable = coolifyServer?.isUsable
            let coolifyDomains = cache.domainsByServerID[server.cacheKey]
                ?? server.coolifyUUID.flatMap { cache.domainsByCoolifyUUID[$0] }
                ?? []
            let metrics = cache.metricsByServerName[server.cacheKey]
                ?? server.hetznerServerName.flatMap { cache.metricsByServerName[$0] }

            var snapshot = HealthRollup.serverSnapshot(
                config: serverConfig,
                endpointChecks: endpointChecks,
                privateProbes: privateProbes,
                coolifyReachable: coolifyReachable,
                containers: containers
            )
            snapshot = ServerSnapshot(
                id: snapshot.id,
                name: snapshot.name,
                overall: snapshot.overall,
                coolifyReachable: snapshot.coolifyReachable,
                coolifyUsable: coolifyUsable,
                hetznerHostName: server.hetznerServerName,
                region: server.region.isEmpty ? nil : server.region,
                privateIP: server.privateIP.isEmpty ? nil : server.privateIP,
                coolifyDomains: coolifyDomains,
                containersRunning: snapshot.containersRunning,
                containersTotal: snapshot.containersTotal,
                cpuPercent: metrics?.cpuPercent,
                ramPercent: metrics?.ramPercent,
                diskMBps: metrics?.diskMBps,
                netInMbps: metrics?.netInMbps,
                endpointChecks: snapshot.endpointChecks,
                privateProbes: snapshot.privateProbes,
                containers: snapshot.containers
            )
            serverSnapshots.append(snapshot)
        }

        return HealthRollup.production(
            servers: serverSnapshots,
            tailscaleConnected: cache.tailscaleConnected,
            now: now
        )
    }
}
