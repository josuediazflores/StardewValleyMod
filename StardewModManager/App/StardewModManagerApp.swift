import SwiftUI

@main
struct StardewModManagerApp: App {
    @State private var appState = AppState()

    init() {
        registerStardewFonts()
    }

    var body: some Scene {
        // Single window: external nxm:// link events reuse it instead of
        // spawning a new window per download
        Window("Stardew Mod Manager", id: "main") {
            ContentView()
                .id("\(appState.settings.theme)-\(appState.settings.language)")
                .environment(appState)
                .onAppear {
                    appState.loadMods()
                    appState.revalidateAPIKeyIfNeeded()
                    appState.checkForAppUpdate()
                    appState.checkForUpdates()
                }
                .onOpenURL { url in
                    appState.handleNXMLink(url)
                }
                .sheet(isPresented: .init(
                    get: { appState.showModpackPicker },
                    set: { appState.showModpackPicker = $0 }
                )) {
                    NXMModpackPickerSheet(importedMods: appState.pendingNXMMods, suggestedModpackName: appState.pendingNXMSuggestedName)
                        .environment(appState)
                }
                .sheet(isPresented: .init(
                    get: { appState.showWebDownloadSheet },
                    set: { appState.showWebDownloadSheet = $0 }
                )) {
                    if let name = appState.webDownloadModName, let url = appState.webDownloadURL {
                        NexusWebDownloadView(modName: name, url: url)
                            .environment(appState)
                    }
                }
                .sheet(isPresented: .init(
                    get: { appState.showAppUpdatePrompt },
                    set: { appState.showAppUpdatePrompt = $0 }
                )) {
                    AppUpdatePromptSheet()
                        .environment(appState)
                }
                .sheet(isPresented: .init(
                    get: { appState.showNexusFilePicker },
                    set: { appState.showNexusFilePicker = $0 }
                )) {
                    NexusFilePickerSheet()
                        .environment(appState)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L.s("menu_import_mods")) {
                    appState.sidebarSelection = .installedMods
                    appState.showImportPicker = true
                }
                .keyboardShortcut("i", modifiers: .command)

                Button(L.s("menu_refresh_mod_list")) {
                    appState.loadMods()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Mods") {
                Button(L.s("menu_launch_game")) {
                    appState.launchGame()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!appState.settings.isSMAPIInstalled)

                Button(L.s("menu_check_updates")) {
                    appState.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: .command)

                Divider()

                Button(L.s("menu_toggle_mod")) {
                    if let mod = appState.selectedMod, !mod.isBuiltIn {
                        if mod.isEnabled {
                            appState.performDisableMod(mod)
                        } else {
                            appState.performEnableMod(mod)
                        }
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.selectedMod == nil || appState.selectedMod?.isBuiltIn == true)

                Button(L.s("menu_show_in_finder")) {
                    if let mod = appState.selectedMod {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(appState.selectedMod == nil)
            }

            CommandGroup(before: .toolbar) {
                Button(L.s("menu_show_all")) {
                    appState.filterMode = .all
                }
                .keyboardShortcut("0", modifiers: .command)

                Button(L.s("menu_show_enabled")) {
                    appState.filterMode = .enabled
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(L.s("menu_show_disabled")) {
                    appState.filterMode = .disabled
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .id("\(appState.settings.theme)-\(appState.settings.language)")
                .environment(appState)
                .preferredColorScheme(appState.settings.theme == .night ? .dark : .light)
        }
    }
}

struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        ZStack {
            VStack(spacing: 0) {
                // Main content
                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: 220)

                    switch appState.sidebarSelection {
                    case .modpacks:
                        ModpackListView()
                    case .installedMods:
                        InstalledModsView()
                    case .browseNexus:
                        NexusBrowseView()
                    case nil:
                        Text(L.s("sidebar_select_item"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            ToastOverlayView()
                .zIndex(0.5)

            if !appState.settings.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(appState.settings.theme == .night ? .dark : .light)
        .background(WindowAccessor())
        .alert(L.s("common_error"), isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button(L.s("common_ok")) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            for pending in appState.pendingDeletions {
                ModManagementService.emptyTrash(stagingURLs: pending.stagingURLs)
            }
        }
    }
}

// MARK: - Window Titlebar Styling

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyTitlebarStyle(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyTitlebarStyle(to: nsView.window)
        }
    }

    private func applyTitlebarStyle(to window: NSWindow?) {
        guard let window else { return }
        window.backgroundColor = NSColor(Color.parchmentHeader)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.toolbar?.isVisible = false
        window.minSize = NSSize(width: 700, height: 450)
        window.collectionBehavior.insert(.fullScreenPrimary)
    }

}
