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
        if dueChannels.contains(.publicHealth) {
            await refreshPublicHealth()
            cache.lastPublicRefresh = now
        }
        if dueChannels.contains(.coolify) {
            await refreshCoolify(credentials: credentials, tailscaleUp: tailscaleUp)
            cache.lastCoolifyRefresh = now
        }
        if dueChannels.contains(.hetzner) {
            await refreshHetzner(credentials: credentials)
            cache.lastHetznerRefresh = now
        }
        if dueChannels.contains(.privateProbes) {
            await refreshPrivateProbes(tailscaleUp: tailscaleUp)
            cache.lastPrivateRefresh = now
        } else if !tailscaleUp {
            applySkippedPrivateProbes()
        }

        operatorHints = buildOperatorHints(credentials: credentials, tailscaleUp: tailscaleUp)
        let production = buildSnapshot(now: now)
        latestSnapshot = production

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

    private func refreshPublicHealth() async {
        for serverConfig in config.servers where !serverConfig.publicEndpoints.isEmpty {
            var checks: [EndpointCheckResult] = []
            for endpoint in serverConfig.publicEndpoints {
                checks.append(await healthProber.probe(endpoint: endpoint))
            }
            cache.endpointChecksByServer[serverConfig.id] = checks
        }
    }

    private func refreshCoolify(credentials: PulseCredentials, tailscaleUp: Bool) async {
        guard let base = credentials.coolifyBaseURL,
              let token = credentials.coolifyToken,
              Self.canReachCoolify(baseURL: base, tailscaleUp: tailscaleUp)
        else {
            cache.coolifyServers = []
            cache.containersByServerName = [:]
            return
        }

        let apiBase = config.coolify.apiBaseURL(host: base)
        let client = coolifyClientFactory(apiBase, token)
        let servers = (try? await client.listServers()) ?? []
        cache.coolifyServers = servers

        var containersByName: [String: [ContainerTile]] = [:]
        for serverConfig in config.servers where serverConfig.coolifyManaged {
            guard let coolifyServer = CoolifyMapper.matchServer(
                configName: serverConfig.hetznerServerName,
                coolifyServers: servers
            ) else { continue }
            if let resources = try? await client.listResources(serverUUID: coolifyServer.uuid) {
                containersByName[serverConfig.hetznerServerName] = CoolifyMapper.containers(from: resources)
            }
        }
        cache.containersByServerName = containersByName
    }

    private func refreshHetzner(credentials: PulseCredentials) async {
        guard let token = credentials.hetznerToken else {
            cache.metricsByServerName = [:]
            return
        }
        let client = hetznerClientFactory(token)
        var metrics: [String: HetznerServerMetrics] = [:]
        for serverConfig in config.servers {
            if let value = try? await client.metrics(forServerName: serverConfig.hetznerServerName) {
                metrics[serverConfig.hetznerServerName] = value
            }
        }
        cache.metricsByServerName = metrics
    }

    private func refreshPrivateProbes(tailscaleUp: Bool) async {
        for serverConfig in config.servers {
            guard !serverConfig.privateProbes.isEmpty else { continue }
            if tailscaleUp {
                var results: [PrivateProbeResult] = []
                for probe in serverConfig.privateProbes {
                    results.append(await privateProber.probe(probe))
                }
                cache.privateProbesByServer[serverConfig.id] = results
            } else {
                cache.privateProbesByServer[serverConfig.id] = serverConfig.privateProbes.map {
                    PrivateProbeResult(id: $0.id, label: $0.label, status: .skipped, message: "tailscale offline")
                }
            }
        }
    }

    private func applySkippedPrivateProbes() {
        for serverConfig in config.servers where !serverConfig.privateProbes.isEmpty {
            cache.privateProbesByServer[serverConfig.id] = serverConfig.privateProbes.map {
                PrivateProbeResult(id: $0.id, label: $0.label, status: .skipped, message: "tailscale offline")
            }
        }
    }

    private func buildOperatorHints(credentials: PulseCredentials, tailscaleUp: Bool) -> OperatorHints {
        var messages: [String] = []
        let coolifyNeedsTailscale = credentials.coolifyBaseURL.map { !Self.coolifyReachableWithoutTailscale(baseURL: $0) } ?? false

        if credentials.coolifyBaseURL == nil || credentials.coolifyToken == nil {
            messages.append("Add Coolify URL + API token in Settings for container status")
        } else if !tailscaleUp && coolifyNeedsTailscale {
            messages.append("Tailscale offline — self-hosted Coolify API paused")
        }
        if !tailscaleUp {
            messages.append("Tailscale offline — private probes paused")
        }
        if credentials.hetznerToken == nil {
            messages.append("Optional: Hetzner token for CPU/RAM (Coolify-only works without it)")
        }
        return OperatorHints(messages: messages)
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
        for serverConfig in config.servers {
            let endpointChecks = cache.endpointChecksByServer[serverConfig.id] ?? []
            let privateProbes = cache.privateProbesByServer[serverConfig.id] ?? []
            let containers = cache.containersByServerName[serverConfig.hetznerServerName] ?? []
            let coolifyReachable = CoolifyMapper.matchServer(
                configName: serverConfig.hetznerServerName,
                coolifyServers: cache.coolifyServers
            )?.isReachable
            let metrics = cache.metricsByServerName[serverConfig.hetznerServerName]

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
                containersRunning: snapshot.containersRunning,
                containersTotal: snapshot.containersTotal,
                cpuPercent: metrics?.cpuPercent,
                ramPercent: metrics?.ramPercent,
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
