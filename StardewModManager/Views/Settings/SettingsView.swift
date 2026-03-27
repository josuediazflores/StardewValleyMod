import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environment(appState)
                .tabItem { Label("General", systemImage: "gear") }

            NexusSettingsTab()
                .environment(appState)
                .tabItem { Label("Nexus", systemImage: "globe") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 300)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
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
        .formStyle(.grouped)
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

// MARK: - Nexus Tab

struct NexusSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var isValidating = false

    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    var body: some View {
        Form {
            LabeledContent("App", value: "Stardew Mod Manager")
            LabeledContent("Version", value: "1.0.0")
        }
        .formStyle(.grouped)
    }
}
