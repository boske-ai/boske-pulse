import AppKit
import BoskePulseCore
import Foundation
import UserNotifications
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: ProductionSnapshot?
    @Published private(set) var config: ProductionConfig?
    @Published private(set) var configError: String?
    @Published private(set) var configSourcePath: String?
    @Published private(set) var operatorHints: OperatorHints = .none
    @Published private(set) var resolvedServerConfigs: [String: ServerConfig] = [:]
    @Published private(set) var isRefreshing = false
    @Published var coolifyBaseURL: String = ""
    @Published var coolifyToken: String = ""
    @Published var hetznerToken: String = ""
    @Published var telegramBotToken: String = ""
    @Published var telegramChatID: String = ""
    @Published private(set) var credentialsSaveMessage: String?
    @Published private(set) var coolifyTestResult: String?
    @Published private(set) var hetznerTestResult: String?
    @Published private(set) var isTestingCoolify = false
    @Published private(set) var isTestingHetzner = false

    private static let pollTickSeconds = 10

    private var engine: PulseEngine?
    private var loopTask: Task<Void, Never>?
    private let credentialsStore = LiveCredentialsStore()
    private let keychain = KeychainService()
    private let snapshotStore = SnapshotStore(appGroupIdentifier: "group.eu.canopystudio.boske.pulse")
    private let notificationDelegate = NotificationDelegate()

    init() {
        configureNotifications()
        requestNotificationPermission()
        loadConfig()
        loadCredentialsFromKeychain()
        startPolling()
    }

    deinit {
        loopTask?.cancel()
    }

    func refreshNow() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await tick(force: true)
    }

    func serverConfig(for id: String) -> ServerConfig? {
        if let resolved = resolvedServerConfigs[id] {
            return resolved
        }
        return config?.servers.first(where: { $0.id == id })
    }

    func loadConfig() {
        configError = nil
        guard let url = ConfigLoader.defaultConfigURL(bundle: .main) else {
            configSourcePath = nil
            configError = "Config not found — run make setup from the repo root, then rebuild in Xcode"
            return
        }
        do {
            config = try ConfigLoader.load(from: url)
            configSourcePath = url.path
            configError = nil
            rebuildEngine()
        } catch {
            configSourcePath = url.path
            configError = "Config error: \(error.localizedDescription)"
        }
    }

    func reloadConfig() {
        loadConfig()
    }

    func saveCredentialsToKeychain() {
        do {
            try keychain.save(coolifyBaseURL, account: "coolifyBaseURL")
            try keychain.save(coolifyToken, account: "coolifyToken")
            try keychain.save(hetznerToken, account: "hetznerToken")
            try keychain.save(telegramBotToken, account: "telegramBotToken")
            try keychain.save(telegramChatID, account: "telegramChatID")
        } catch {
            credentialsSaveMessage = "Keychain save failed — try again"
            return
        }
        credentialsSaveMessage = "Saved to Keychain"
        coolifyTestResult = nil
        hetznerTestResult = nil
        rebuildEngine()
        Task { await refreshNow() }
    }

    func testCoolifyConnection() async {
        isTestingCoolify = true
        coolifyTestResult = nil
        defer { isTestingCoolify = false }

        guard let base = URL(string: coolifyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              SecurityPolicy.isAllowedCoolifyBaseURL(base),
              !resolvedCoolifyToken().isEmpty
        else {
            coolifyTestResult = "Enter a valid HTTPS (or HTTP tailnet) Coolify URL and API token"
            return
        }

        let coolifyConfig = config?.coolify ?? .default
        let apiBase = coolifyConfig.apiBaseURL(host: base)
        let client = LiveCoolifyClient(baseURL: apiBase, token: resolvedCoolifyToken()!)
        do {
            let servers = try await client.listServers()
            let names = servers.map(\.name).sorted().joined(separator: ", ")
            coolifyTestResult = "Connected — \(servers.count) server(s): \(names)"
        } catch {
            coolifyTestResult = "Failed — \(error.localizedDescription)"
        }
    }

    func testHetznerConnection() async {
        isTestingHetzner = true
        hetznerTestResult = nil
        defer { isTestingHetzner = false }

        guard let token = resolvedHetznerToken() else {
            hetznerTestResult = "Enter Hetzner API token"
            return
        }

        let client = LiveHetznerClient(token: token)
        do {
            let hosts = try await client.listHosts()
            let names = hosts.map(\.name).sorted().joined(separator: ", ")
            hetznerTestResult = "Connected — \(hosts.count) server(s): \(names)"
        } catch {
            hetznerTestResult = "Failed — \(error.localizedDescription)"
        }
    }

    func openCoolify() {
        if let base = URL(string: coolifyBaseURL), SecurityPolicy.isAllowedCoolifyBaseURL(base) {
            NSWorkspace.shared.open(base)
            return
        }
        if let url = URL(string: "https://console.hetzner.cloud/") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCoolify(for serverID: String) {
        guard let server = serverConfig(for: serverID), server.coolifyManaged else { return }
        openCoolify()
    }

    func copySSH(for serverID: String) {
        guard let server = serverConfig(for: serverID) else { return }
        let command = SecurityPolicy.sshCommand(host: server.publicIPv4) ?? validatedSSHCommand(server.links.ssh)
        guard let command else { return }
        PulseClipboard.copy(command)
    }

    func copyServerSummary(for serverID: String) {
        guard let server = snapshot?.servers.first(where: { $0.id == serverID }) else { return }
        PulseClipboard.copy(ServerCopyFormatter.text(for: server, config: serverConfig(for: serverID)))
    }

    func copyText(_ text: String) {
        PulseClipboard.copy(text)
    }

    func openHetzner(for serverID: String? = nil) {
        let urlString: String
        if let serverID, let server = serverConfig(for: serverID) {
            urlString = server.links.hetzner
        } else {
            urlString = "https://console.hetzner.cloud/"
        }
        guard SecurityPolicy.isAllowedBrowserURL(urlString), let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func openEndpoint(_ urlString: String) {
        guard SecurityPolicy.isAllowedBrowserURL(urlString), let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func muteAlerts(for hours: Double = 1) {
        Task {
            await engine?.acknowledgeAlerts(for: hours * 3600)
        }
    }

    private func configureNotifications() {
        let mute = UNNotificationAction(
            identifier: NotificationDelegate.muteActionID,
            title: "Mute 1 hour",
            options: []
        )
        let categories = ["PRODUCTION_DOWN", "SERVER_DEGRADED", "DEPLOY_FAILED"].map {
            UNNotificationCategory(identifier: $0, actions: [mute], intentIdentifiers: [], options: [])
        }
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
        notificationDelegate.onMute = { [weak self] in
            self?.muteAlerts()
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    private func requestNotificationPermission() {
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    private func loadCredentialsFromKeychain() {
        coolifyBaseURL = keychain.load(account: "coolifyBaseURL") ?? ""
        coolifyToken = keychain.load(account: "coolifyToken") ?? ""
        hetznerToken = keychain.load(account: "hetznerToken") ?? ""
        telegramBotToken = keychain.load(account: "telegramBotToken") ?? ""
        telegramChatID = keychain.load(account: "telegramChatID") ?? ""
        rebuildEngine()
    }

    private func rebuildEngine() {
        guard let config else { return }
        syncCredentialsStore()
        engine = PulseEngine(
            config: config,
            credentialsStore: credentialsStore,
            tailscale: TailscaleCLIReachability(),
            onAlert: { [weak self] snap, message in
                await self?.handleAlert(snapshot: snap, message: message)
            }
        )
    }

    private func syncCredentialsStore() {
        credentialsStore.update(currentCredentials())
    }

    private func currentCredentials() -> PulseCredentials {
        PulseCredentials(
            coolifyBaseURL: URL(string: (keychain.load(account: "coolifyBaseURL") ?? coolifyBaseURL).trimmingCharacters(in: .whitespacesAndNewlines)),
            coolifyToken: resolvedCoolifyToken(),
            hetznerToken: resolvedHetznerToken(),
            telegramBotToken: resolvedTelegramBotToken(),
            telegramChatID: resolvedTelegramChatID()
        )
    }

    private func resolvedCoolifyToken() -> String? {
        tokenValue(field: coolifyToken, account: "coolifyToken")
    }

    private func resolvedHetznerToken() -> String? {
        tokenValue(field: hetznerToken, account: "hetznerToken")
    }

    private func resolvedTelegramBotToken() -> String? {
        tokenValue(field: telegramBotToken, account: "telegramBotToken")
    }

    private func resolvedTelegramChatID() -> String? {
        tokenValue(field: telegramChatID, account: "telegramChatID")
    }

    private func tokenValue(field: String, account: String) -> String? {
        let persisted = keychain.load(account: account) ?? ""
        let value = field.isEmpty ? persisted : field
        return value.isEmpty ? nil : value
    }

    private func validatedSSHCommand(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("ssh ") else { return nil }
        let remainder = trimmed.dropFirst(4)
        let parts = remainder.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return SecurityPolicy.sshCommand(host: String(parts[1]))
    }

    private func startPolling() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick(force: false)
                try? await Task.sleep(nanoseconds: UInt64(Self.pollTickSeconds * 1_000_000_000))
            }
        }
    }

    private func tick(force: Bool) async {
        guard let engine else { return }
        syncCredentialsStore()
        let snap = await engine.refresh(force: force)
        snapshot = snap
        operatorHints = await engine.operatorHints
        let resolved = await engine.resolvedServers
        resolvedServerConfigs = Dictionary(resolved.map { ($0.id, $0.asServerConfig()) }, uniquingKeysWith: { first, _ in first })
        try? snapshotStore.write(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleAlert(snapshot: ProductionSnapshot, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Boske Pulse"
        content.body = snapshot.smokeSummary
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier(for: snapshot.overall)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        try? await UNUserNotificationCenter.current().add(request)
        if config?.alerts.telegramEnabled == true,
           let botToken = resolvedTelegramBotToken(),
           let chatID = resolvedTelegramChatID()
        {
            try? await TelegramNotifier().send(botToken: botToken, chatID: chatID, text: message)
        }
    }

    private func categoryIdentifier(for overall: OverallHealth) -> String {
        switch overall {
        case .down: return "PRODUCTION_DOWN"
        case .degraded: return "SERVER_DEGRADED"
        case .healthy, .unknown: return "SERVER_DEGRADED"
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let muteActionID = "MUTE_1H"

    var onMute: (() -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == Self.muteActionID {
            onMute?()
        }
    }
}
