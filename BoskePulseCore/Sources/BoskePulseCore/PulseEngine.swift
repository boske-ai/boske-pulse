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

    private(set) public var latestSnapshot: ProductionSnapshot?

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

    @discardableResult
    public func refresh() async -> ProductionSnapshot {
        let credentials = credentialsStore.load()
        let tailscaleUp = await tailscale.isConnected()

        var coolifyServers: [CoolifyServer] = []
        if tailscaleUp,
           let base = credentials.coolifyBaseURL,
           let token = credentials.coolifyToken
        {
            let apiBase = config.coolify.apiBaseURL(host: base)
            let client = coolifyClientFactory(apiBase, token)
            coolifyServers = (try? await client.listServers()) ?? []
        }

        let hetznerClient: (any HetznerClient)?
        if let token = credentials.hetznerToken {
            hetznerClient = hetznerClientFactory(token)
        } else {
            hetznerClient = nil
        }

        var serverSnapshots: [ServerSnapshot] = []
        for serverConfig in config.servers {
            var endpointChecks: [EndpointCheckResult] = []
            for endpoint in serverConfig.publicEndpoints {
                let check = await healthProber.probe(endpoint: endpoint)
                endpointChecks.append(check)
            }

            var privateResults: [PrivateProbeResult] = []
            if tailscaleUp {
                for probe in serverConfig.privateProbes {
                    let result = await privateProber.probe(probe)
                    privateResults.append(result)
                }
            } else if !serverConfig.privateProbes.isEmpty {
                privateResults = serverConfig.privateProbes.map {
                    PrivateProbeResult(id: $0.id, label: $0.label, status: .skipped, message: "tailscale offline")
                }
            }

            var containers: [ContainerTile] = []
            var coolifyReachable: Bool?
            if let coolifyServer = CoolifyMapper.matchServer(configName: serverConfig.hetznerServerName, coolifyServers: coolifyServers) {
                coolifyReachable = coolifyServer.isReachable
                if tailscaleUp,
                   let base = credentials.coolifyBaseURL,
                   let token = credentials.coolifyToken
                {
                    let apiBase = config.coolify.apiBaseURL(host: base)
                    let client = coolifyClientFactory(apiBase, token)
                    if let resources = try? await client.listResources(serverUUID: coolifyServer.uuid) {
                        containers = CoolifyMapper.containers(from: resources)
                    }
                }
            }

            var cpu: Double?
            var ram: Double?
            if let hetznerClient {
                let metrics = try? await hetznerClient.metrics(forServerName: serverConfig.hetznerServerName)
                cpu = metrics?.cpuPercent
                ram = metrics?.ramPercent
            }

            var snapshot = HealthRollup.serverSnapshot(
                config: serverConfig,
                endpointChecks: endpointChecks,
                privateProbes: privateResults,
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
                cpuPercent: cpu,
                ramPercent: ram,
                endpointChecks: snapshot.endpointChecks,
                privateProbes: snapshot.privateProbes,
                containers: snapshot.containers
            )
            serverSnapshots.append(snapshot)
        }

        let production = HealthRollup.production(servers: serverSnapshots, tailscaleConnected: tailscaleUp)
        latestSnapshot = production

        let decision = debouncer.evaluate(overall: production.overall)
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
}
