import SwiftUI

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case nexus = "Nexus"
    case about = "About"

    var id: String { rawValue }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.stardew(size: 18))
                            .lineLimit(1)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == tab
                                    ? RoundedRectangle(cornerRadius: 4).fill(Color.accentGold)
                                    : nil
                            )
                            .foregroundStyle(
                                selectedTab == tab
                                    ? Color.textDark
                                    : Color.textMuted
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.parchmentHeader)

            Divider().overlay(Color.stardewDivider)

            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab()
                        .environment(appState)
                case .nexus:
                    NexusSettingsTab()
                        .environment(appState)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.parchment)
        .frame(width: 520, height: 400)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 16) {
            // Theme picker
            HStack(spacing: 12) {
                Text("Theme")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textDark)
                    .frame(width: 160, alignment: .leading)

                HStack(spacing: 0) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                appState.settings.theme = theme
                            }
                        } label: {
                            Text(theme.rawValue)
                                .font(.stardew(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .background(
                                    appState.settings.theme == theme
                                        ? RoundedRectangle(cornerRadius: 4).fill(Color.accentGold)
                                        : nil
                                )
                                .foregroundStyle(
                                    appState.settings.theme == theme
                                        ? Color.textDark
                                        : Color.textMuted
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.stardewDivider, lineWidth: 1)
                )

                Spacer()
            }

            // Game path card
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Stardew Valley Location")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                        .frame(width: 160, alignment: .leading)

                    Text(appState.settings.gamePath)
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Browse...") {
                        browseGamePath()
                    }
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentGold)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentGoldBorder, lineWidth: 1)
                            )
                    )
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider().overlay(Color.stardewDivider)

                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.settings.isGamePathValid ? Color.stardewGreen : Color.stardewRed)
                            .frame(width: 8, height: 8)
                        Text(appState.settings.isGamePathValid ? "Game found" : "Game not found")
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isGamePathValid ? Color.stardewGreen : Color.stardewRed)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                            .frame(width: 8, height: 8)
                        Text(appState.settings.isSMAPIInstalled ? "SMAPI installed" : "SMAPI not found")
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                    }

                    if !appState.settings.isSMAPIInstalled {
                        Button("Install SMAPI") {
                            if let url = URL(string: "https://smapi.io") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.stardewBlue)
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.parchmentAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.stardewDivider, lineWidth: 1)
                    )
            )

            // Auto-Detect button
            Button {
                if let path = GamePathDetector.detect() {
                    appState.settings.gamePath = path
                    appState.loadMods()
                }
            } label: {
                Text("Auto-Detect")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textDark)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentGold)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentGoldBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Text("Changes to game path take effect after reloading the mod list (\u{2318}R).")
                .font(.stardew(size: 13))
                .foregroundStyle(Color.textMuted)

            Spacer()
        }
        .padding(24)
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                if appState.settings.isAPIKeyValidated {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.stardewGreen)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.stardewGreen)
                        if let name = appState.settings.nexusUserName {
                            Text("as \(name)")
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.textMuted)
                        }
                        if appState.settings.isNexusPremium {
                            Text("Premium")
                                .font(.stardew(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.stardewOrange.opacity(0.2))
                                .foregroundStyle(Color.stardewOrange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)

                    Divider().overlay(Color.stardewDivider)

                    HStack {
                        Button {
                            appState.settings.nexusAPIKey = nil
                            appState.settings.isAPIKeyValidated = false
                            appState.settings.nexusUserName = nil
                            appState.settings.isNexusPremium = false
                        } label: {
                            Text("Disconnect")
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.stardewRed)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.stardewRed, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(14)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nexus Mods API Key")
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.textDark)

                        SecureField("Enter API key...", text: $apiKeyInput)
                            .font(.stardew(size: 14))
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            Button {
                                isValidating = true
                                Task {
                                    await appState.validateNexusAPIKey(apiKeyInput)
                                    isValidating = false
                                }
                            } label: {
                                Text("Validate & Save")
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(Color.textDark)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.accentGold)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color.accentGoldBorder, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(apiKeyInput.isEmpty || isValidating)
                            .opacity(apiKeyInput.isEmpty || isValidating ? 0.5 : 1)

                            Button("Get API Key") {
                                if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.stardewBlue)
                            .buttonStyle(.plain)

                            if isValidating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    .padding(14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.parchmentAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.stardewDivider, lineWidth: 1)
                    )
            )

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("App")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 80, alignment: .leading)
                    Text("Stardew Mod Manager")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                    Spacer()
                }
                .padding(14)

                Divider().overlay(Color.stardewDivider)

                HStack {
                    Text("Version")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 80, alignment: .leading)
                    Text("1.0.0")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                    Spacer()
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.parchmentAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.stardewDivider, lineWidth: 1)
                    )
            )

            Spacer()
        }
        .padding(24)
    }
}
