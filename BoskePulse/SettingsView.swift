import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            if let configError = model.configError {
                Section {
                    Text(configError)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Reload config") {
                        model.reloadConfig()
                    }
                }
            }

            Section {
                Text("API tokens are stored in the macOS Keychain (encrypted on disk, this device only). The app reads them while running to poll your infrastructure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Copied SSH commands are cleared from the clipboard after one minute. Paste them into an SSH client, not a shell.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Coolify (required for containers)") {
                TextField("Base URL", text: $model.coolifyBaseURL, prompt: Text("https://app.coolify.io"))
                    .textFieldStyle(.roundedBorder)
                Text("Coolify Cloud: https://app.coolify.io · Self-hosted: your Tailscale URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section("Hetzner Cloud (required for non-Coolify servers)") {
                Text("Needed to discover Hetzner hosts that are not managed by Coolify (for example data or search nodes). Save to Keychain after entering the token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
