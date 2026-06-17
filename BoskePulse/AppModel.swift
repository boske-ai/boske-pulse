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
    @Published private(set) var operatorHints: OperatorHints = .none
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
        config?.servers.first(where: { $0.id == id })
    }

    func loadConfig() {
        configError = nil
        guard let url = ConfigLoader.defaultConfigURL(bundle: .main) else {
            configError = "Config not found — run: make setup"
            return
        }
        do {
            config = try ConfigLoader.load(from: url)
            rebuildEngine()
        } catch {
            configError = error.localizedDescription
        }
    }

    func saveCredentialsToKeychain() {
        keychain.save(coolifyBaseURL, account: "coolifyBaseURL")
        keychain.save(coolifyToken, account: "coolifyToken")
        keychain.save(hetznerToken, account: "hetznerToken")
        keychain.save(telegramBotToken, account: "telegramBotToken")
        keychain.save(telegramChatID, account: "telegramChatID")
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

        guard let config else {
            coolifyTestResult = "Config not loaded"
            return
        }
        guard let base = URL(string: coolifyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              !coolifyToken.isEmpty
        else {
            coolifyTestResult = "Enter Coolify base URL and API token"
            return
        }

        let apiBase = config.coolify.apiBaseURL(host: base)
        let client = LiveCoolifyClient(baseURL: apiBase, token: coolifyToken)
        do {
            let servers = try await client.listServers()
            coolifyTestResult = "Connected — \(servers.count) server(s) in Coolify"
        } catch {
            coolifyTestResult = "Failed — \(error.localizedDescription)"
        }
    }

    func testHetznerConnection() async {
        isTestingHetzner = true
        hetznerTestResult = nil
        defer { isTestingHetzner = false }

        guard !hetznerToken.isEmpty else {
            hetznerTestResult = "Enter Hetzner API token"
            return
        }

        let client = LiveHetznerClient(token: hetznerToken)
        do {
            let names = try await client.listServerNames()
            hetznerTestResult = "Connected — \(names.count) server(s) in project"
        } catch {
            hetznerTestResult = "Failed — \(error.localizedDescription)"
        }
    }

    func openCoolify() {
        if let base = URL(string: coolifyBaseURL) {
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.links.ssh, forType: .string)
    }

    func openHetzner(for serverID: String? = nil) {
        let urlString: String
        if let serverID, let server = serverConfig(for: serverID) {
            urlString = server.links.hetzner
        } else {
            urlString = "https://console.hetzner.cloud/"
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func openEndpoint(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
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
        let credentials = PulseCredentials(
            coolifyBaseURL: URL(string: coolifyBaseURL),
            coolifyToken: coolifyToken.isEmpty ? nil : coolifyToken,
            hetznerToken: hetznerToken.isEmpty ? nil : hetznerToken,
            telegramBotToken: telegramBotToken.isEmpty ? nil : telegramBotToken,
            telegramChatID: telegramChatID.isEmpty ? nil : telegramChatID
        )
        engine = PulseEngine(
            config: config,
            credentialsStore: InMemoryCredentialsStore(credentials: credentials),
            tailscale: TailscaleCLIReachability(),
            onAlert: { [weak self] snap, message in
                await self?.handleAlert(snapshot: snap, message: message)
            }
        )
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
        let snap = await engine.refresh(force: force)
        snapshot = snap
        operatorHints = await engine.operatorHints
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
           !telegramBotToken.isEmpty,
           !telegramChatID.isEmpty
        {
            try? await TelegramNotifier().send(botToken: telegramBotToken, chatID: telegramChatID, text: message)
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
