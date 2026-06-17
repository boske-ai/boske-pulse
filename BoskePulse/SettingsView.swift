import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Text("Secrets are stored in macOS Keychain only — never on disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Coolify (Tailscale URL)") {
                TextField("Base URL", text: $model.coolifyBaseURL, prompt: Text("http://100.x.x.x:8000"))
                    .textFieldStyle(.roundedBorder)
                SecureField("API token", text: $model.coolifyToken)
                HStack {
                    Button("Test Coolify") {
                        Task { await model.testCoolifyConnection() }
                    }
                    .disabled(model.isTestingCoolify)
                    if model.isTestingCoolify {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let result = model.coolifyTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("Connected") ? .green : .red)
                }
            }

            Section("Hetzner Cloud") {
                SecureField("Read-only API token", text: $model.hetznerToken)
                HStack {
                    Button("Test Hetzner") {
                        Task { await model.testHetznerConnection() }
                    }
                    .disabled(model.isTestingHetzner)
                    if model.isTestingHetzner {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let result = model.hetznerTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("Connected") ? .green : .red)
                }
            }

            Section("Telegram (phone alerts)") {
                SecureField("Bot token", text: $model.telegramBotToken)
                TextField("Chat ID", text: $model.telegramChatID)
            }

            Section {
                Button("Save to Keychain") {
                    model.saveCredentialsToKeychain()
                }
                if let message = model.credentialsSaveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(width: 520, height: 480)
    }
}
