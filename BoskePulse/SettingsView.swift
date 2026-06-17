import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Coolify (Tailscale URL)") {
                TextField("Base URL", text: $model.coolifyBaseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API token", text: $model.coolifyToken)
            }
            Section("Hetzner Cloud") {
                SecureField("Read-only API token", text: $model.hetznerToken)
            }
            Section("Telegram (phone alerts)") {
                SecureField("Bot token", text: $model.telegramBotToken)
                TextField("Chat ID", text: $model.telegramChatID)
            }
            Button("Save to Keychain") {
                model.saveCredentialsToKeychain()
            }
        }
        .padding()
        .frame(width: 480, height: 360)
    }
}
