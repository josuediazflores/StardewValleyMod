import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var isValidating = false

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Game Path") {
                LabeledContent("Stardew Valley Location") {
                    HStack {
                        Text(appState.settings.gamePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button("Browse...") {
                            browseGamePath()
                        }
                    }
                }

                HStack {
                    if appState.settings.isGamePathValid {
                        Label("Game found", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Game not found", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    if appState.settings.isSMAPIInstalled {
                        Label("SMAPI installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("SMAPI not found", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)

                        Button("Install SMAPI") {
                            if let url = URL(string: "https://smapi.io") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.caption)

                Button("Auto-Detect") {
                    if let path = GamePathDetector.detect() {
                        appState.settings.gamePath = path
                        appState.loadMods()
                    }
                }
            }

            Section("Nexus Mods") {
                if appState.settings.isAPIKeyValidated {
                    HStack {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if let name = appState.settings.nexusUserName {
                            Text("as \(name)")
                                .foregroundStyle(.secondary)
                        }
                        if appState.settings.isNexusPremium {
                            Text("Premium")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.yellow.opacity(0.2))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }
                    }

                    Button("Disconnect") {
                        appState.settings.nexusAPIKey = nil
                        appState.settings.isAPIKeyValidated = false
                        appState.settings.nexusUserName = nil
                        appState.settings.isNexusPremium = false
                    }
                    .foregroundStyle(.red)
                } else {
                    SecureField("API Key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Validate & Save") {
                            isValidating = true
                            Task {
                                await appState.validateNexusAPIKey(apiKeyInput)
                                isValidating = false
                            }
                        }
                        .disabled(apiKeyInput.isEmpty || isValidating)

                        Button("Get API Key") {
                            if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    if isValidating {
                        ProgressView()
                    }
                }
            }

            Section("About") {
                LabeledContent("App", value: "Stardew Mod Manager")
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func browseGamePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Stardew Valley Game Directory"
        panel.message = "Navigate to the folder containing StardewModdingAPI"

        if panel.runModal() == .OK, let url = panel.url {
            appState.settings.gamePath = url.path(percentEncoded: false)
            appState.loadMods()
        }
    }
}
