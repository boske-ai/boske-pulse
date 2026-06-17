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
    @Published private(set) var isRefreshing = false
    @Published var coolifyBaseURL: String = ""
    @Published var coolifyToken: String = ""
    @Published var hetznerToken: String = ""
    @Published var telegramBotToken: String = ""
    @Published var telegramChatID: String = ""

    private var engine: PulseEngine?
    private var loopTask: Task<Void, Never>?
    private let keychain = KeychainService()
    private let snapshotStore = SnapshotStore(appGroupIdentifier: "group.eu.canopystudio.boske.pulse")

    init() {
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
        await tick()
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
        rebuildEngine()
    }

    func openCoolify() {
        guard let base = URL(string: coolifyBaseURL) else { return }
        NSWorkspace.shared.open(base)
    }

    func copySSH(for serverID: String) {
        guard let server = config?.servers.first(where: { $0.id == serverID }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.links.ssh, forType: .string)
    }

    func openHetzner() {
        guard let url = URL(string: "https://console.hetzner.cloud/") else { return }
        NSWorkspace.shared.open(url)
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
                await self?.tick()
                let interval = UInt64((self?.config?.polling.publicHealthSeconds ?? 30) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func tick() async {
        guard let engine else { return }
        let snap = await engine.refresh()
        snapshot = snap
        try? snapshotStore.write(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleAlert(snapshot: ProductionSnapshot, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Boske Pulse"
        content.body = snapshot.smokeSummary
        content.sound = .default
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
}
