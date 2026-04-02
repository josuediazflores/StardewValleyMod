import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch currentStep {
                case 0:
                    WelcomeStepView()
                case 1:
                    GamePathStepView()
                case 2:
                    NexusKeyStepView()
                case 3:
                    OrientationStepView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            .id(currentStep)

            // Bottom navigation
            VStack(spacing: 16) {
                Color.frameBorder.frame(height: 2)

                HStack {
                    // Back button
                    if currentStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11))
                                Text(L.s("onboarding_back"))
                                    .font(.stardew(size: 18))
                            }
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 80)
                    }

                    Spacer()

                    // Dot indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { step in
                            Circle()
                                .fill(step == currentStep ? Color.accentGold : Color.toggleOff.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Spacer()

                    // Next / Get Started button
                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            appState.createInitialModpackIfNeeded()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState.settings.hasCompletedOnboarding = true
                            }
                        }
                    } label: {
                        Text(nextButtonText)
                            .font(.stardew(size: 18))
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(Color.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.frameBorder, lineWidth: 4)
        )
    }

    private var nextButtonText: String {
        switch currentStep {
        case 2:
            return appState.settings.isAPIKeyValidated ? L.s("onboarding_next") : L.s("onboarding_skip")
        case 3:
            return L.s("onboarding_get_started")
        default:
            return L.s("onboarding_next")
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            JunimoIcon(name: appState.selectedJunimoName, size: 80)

            Text(L.s("onboarding_welcome"))
                .font(.stardew(size: 32))
                .foregroundStyle(Color.textDark)
                .multilineTextAlignment(.center)

            Text(L.s("onboarding_welcome_desc"))
                .font(.stardew(size: 18))
                .foregroundStyle(Color.textMedium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Text(L.s("onboarding_welcome_hint"))
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMuted)

            Spacer()
        }
        .padding(32)
    }
}

// MARK: - Step 1: Game Path

private struct GamePathStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(L.s("onboarding_find_game"))
                .font(.stardew(size: 28))
                .foregroundStyle(Color.textDark)

            Text(L.s("onboarding_game_location"))
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMedium)

            // Game path card
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(appState.settings.gamePath.isEmpty ? L.s("onboarding_no_path") : appState.settings.gamePath)
                        .font(.stardew(size: 14))
                        .foregroundStyle(appState.settings.gamePath.isEmpty ? Color.stardewRed : Color.textMuted)
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
                        Text(appState.settings.isGamePathValid ? L.s("onboarding_game_found") : L.s("onboarding_game_not_found"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isGamePathValid ? Color.stardewGreen : Color.stardewRed)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                            .frame(width: 8, height: 8)
                        Text(appState.settings.isSMAPIInstalled ? L.s("onboarding_smapi_installed") : L.s("onboarding_smapi_not_found"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                    }

                    if !appState.settings.isSMAPIInstalled {
                        if appState.isSMAPIInstalling {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(L.s("onboarding_installing"))
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(Color.textMuted)
                            }
                        } else {
                            Button {
                                appState.installSMAPI()
                            } label: {
                                Text(L.s("onboarding_install_smapi"))
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
            .frame(maxWidth: 500)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.parchmentAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.stardewDivider, lineWidth: 1)
                    )
            )

            Button {
                if let path = GamePathDetector.detect() {
                    appState.settings.gamePath = path
                    appState.loadMods()
                }
            } label: {
                Text(L.s("onboarding_auto_detect"))
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
        .padding(32)
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

// MARK: - Step 2: Nexus API Key

private struct NexusKeyStepView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(L.s("onboarding_nexus_title"))
                .font(.stardew(size: 28))
                .foregroundStyle(Color.textDark)

            Text(L.s("onboarding_nexus_desc"))
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMedium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)

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
                } else {
                    VStack(spacing: 12) {
                        SecureField(L.s("nexus_api_placeholder"), text: $apiKeyInput)
                            .font(.stardew(size: 14))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 400)

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

                        if let error = appState.nexusError {
                            Text(error)
                                .font(.stardew(size: 13))
                                .foregroundStyle(Color.stardewRed)
                        }
                    }
                    .padding(14)
                }
            }
            .frame(maxWidth: 500)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.parchmentAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.stardewDivider, lineWidth: 1)
                    )
            )

            Text(L.s("onboarding_setup_later"))
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)

            Spacer()
        }
        .padding(32)
    }
}

// MARK: - Step 3: Orientation

private struct OrientationStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(L.s("onboarding_all_set"))
                .font(.stardew(size: 28))
                .foregroundStyle(Color.textDark)

            Text(L.s("onboarding_all_set_hint"))
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMedium)

            VStack(spacing: 12) {
                orientationCard(
                    imageName: "Golden_Scroll",
                    title: L.s("onboarding_profiles_title"),
                    description: L.s("onboarding_profiles_desc")
                )
                orientationCard(
                    imageName: "Chest",
                    title: L.s("onboarding_mods_title"),
                    description: L.s("onboarding_mods_desc")
                )
                orientationCard(
                    imageName: "Horse_The_Book",
                    title: L.s("onboarding_browse_title"),
                    description: L.s("onboarding_browse_desc")
                )
            }
            .frame(maxWidth: 450)

            Spacer()
        }
        .padding(32)
    }

    private func orientationCard(imageName: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            if let url = Bundle.appBundle.url(forResource: imageName, withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.stardew(size: 20))
                    .foregroundStyle(Color.textDark)
                Text(description)
                    .font(.stardew(size: 15))
                    .foregroundStyle(Color.textMedium)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.parchmentAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.frameBorder, lineWidth: 2)
                )
        )
    }
}
