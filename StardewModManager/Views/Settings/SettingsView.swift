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
        .frame(width: 520, height: 460)
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
                Text(L.s("settings_theme"))
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

            // Language picker
            HStack(spacing: 12) {
                Text(L.s("settings_language"))
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textDark)
                    .frame(width: 160, alignment: .leading)

                Picker("", selection: Binding(
                    get: { appState.settings.language },
                    set: { appState.settings.language = $0 }
                )) {
                    Text(L.s("settings_language_system")).tag("system")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("Français").tag("fr")
                    Text("Deutsch").tag("de")
                    Text("Italiano").tag("it")
                    Text("Português").tag("pt")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                    Text("简体中文").tag("zh-Hans")
                    Text("Русский").tag("ru")
                }
                .labelsHidden()
                .frame(width: 160)

                Spacer()
            }

            // Sound effects toggle
            HStack(spacing: 12) {
                Text(L.s("settings_sounds"))
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textDark)
                    .frame(width: 160, alignment: .leading)

                Toggle("", isOn: Binding(
                    get: { appState.settings.enableSounds },
                    set: { appState.settings.enableSounds = $0 }
                ))
                .toggleStyle(StardewToggleStyle())

                Spacer()
            }

            // Game path card
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(L.s("settings_game_location"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                        .frame(width: 160, alignment: .leading)

                    Text(appState.settings.gamePath)
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(L.s("common_browse")) {
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
                        Text(appState.settings.isGamePathValid ? L.s("settings_game_found") : L.s("settings_game_not_found"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isGamePathValid ? Color.stardewGreen : Color.stardewRed)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                            .frame(width: 8, height: 8)
                        Text(appState.settings.isSMAPIInstalled ? L.s("settings_smapi_installed") : L.s("settings_smapi_not_found"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                    }

                    if !appState.settings.isSMAPIInstalled {
                        if appState.isSMAPIInstalling {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(L.s("settings_installing"))
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(Color.textMuted)
                            }
                        } else {
                            Button {
                                appState.installSMAPI()
                            } label: {
                                Text(L.s("settings_install_smapi"))
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(Color.textDark)
                                    .padding(.horizontal, 12)
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
                        }
                    }
                }
                .padding(12)

                if let error = appState.smapiInstallError {
                    VStack(spacing: 6) {
                        Text(error)
                            .font(.stardew(size: 12))
                            .foregroundStyle(Color.stardewRed)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Button(L.s("common_retry")) { appState.installSMAPI() }
                                .font(.stardew(size: 12))
                                .foregroundStyle(Color.stardewBlue)
                                .buttonStyle(.plain)
                            Button(L.s("settings_manual_install")) {
                                if let url = URL(string: "https://smapi.io") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.stardew(size: 12))
                            .foregroundStyle(Color.textMuted)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
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

            // Auto-Detect button
            Button {
                if let path = GamePathDetector.detect() {
                    appState.settings.gamePath = path
                    appState.loadMods()
                }
            } label: {
                Text(L.s("settings_auto_detect"))
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

            Text(L.s("settings_reload_hint"))
                .font(.stardew(size: 13))
                .foregroundStyle(Color.textMuted)

            Button {
                appState.settings.hasCompletedOnboarding = false
            } label: {
                Text(L.s("settings_show_welcome"))
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

            Spacer()
        }
        .padding(24)
    }

    private func browseGamePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = L.s("onboarding_game_dir")
        panel.message = L.s("onboarding_game_dir_hint")

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
                        Text(L.s("onboarding_connected"))
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.stardewGreen)
                        if let name = appState.settings.nexusUserName {
                            Text(L.s("onboarding_nexus_as", name))
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.textMuted)
                        }
                        if appState.settings.isNexusPremium {
                            Text(L.s("onboarding_premium"))
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
                            Text(L.s("settings_disconnect"))
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
                        Text(L.s("settings_nexus_api"))
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.textDark)

                        SecureField(L.s("settings_nexus_placeholder"), text: $apiKeyInput)
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
                                Text(L.s("nexus_validate"))
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

                            Button(L.s("nexus_get_key")) {
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
    @Environment(AppState.self) private var appState
    @State private var isChecking = false
    @State private var checkResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text(L.s("settings_app"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 80, alignment: .leading)
                    Text(L.s("settings_app_name"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                    Spacer()
                }
                .padding(14)

                Divider().overlay(Color.stardewDivider)

                HStack {
                    Text(L.s("settings_version"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                        .frame(width: 80, alignment: .leading)
                    Text(UpdateService.currentVersion)
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

            HStack(spacing: 12) {
                Button {
                    isChecking = true
                    checkResult = nil
                    Task {
                        let update = await UpdateService.checkForUpdate()
                        appState.availableUpdate = update
                        if let update {
                            checkResult = L.s("settings_update_available", update.version)
                        } else {
                            checkResult = L.s("settings_up_to_date")
                        }
                        isChecking = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        Text(L.s("settings_check_updates"))
                            .font(.stardew(size: 16))
                    }
                    .foregroundStyle(Color.textDark)
                    .padding(.horizontal, 16)
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
                .disabled(isChecking)

                if let result = checkResult {
                    Text(result)
                        .font(.stardew(size: 14))
                        .foregroundStyle(appState.availableUpdate != nil ? Color.stardewOrange : Color.stardewGreen)
                }
            }

            if let update = appState.availableUpdate {
                if appState.isUpdating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(L.s("update_downloading"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    }
                } else {
                    HStack(spacing: 12) {
                        Button {
                            appState.performAppUpdate()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                Text(L.s("settings_update_to", update.version))
                                    .font(.stardew(size: 16))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.stardewOrange)
                            )
                        }
                        .buttonStyle(.plain)

                        Button(L.s("settings_view_notes")) {
                            if let url = URL(string: update.htmlURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.stardewBlue)
                        .buttonStyle(.plain)
                    }
                }

                if let error = appState.updateError {
                    Text(error)
                        .font(.stardew(size: 13))
                        .foregroundStyle(Color.stardewRed)
                }
            }

            Spacer()
        }
        .padding(24)
    }
}
