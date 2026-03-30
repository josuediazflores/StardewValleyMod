import SwiftUI

@main
struct StardewModManagerApp: App {
    @State private var appState = AppState()

    init() {
        registerStardewFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appState.settings.theme)
                .environment(appState)
                .onAppear {
                    appState.loadMods()
                    appState.revalidateAPIKeyIfNeeded()
                    appState.checkForAppUpdate()
                }
                .onOpenURL { url in
                    appState.handleNXMLink(url)
                }
                .sheet(isPresented: .init(
                    get: { appState.showModpackPicker },
                    set: { appState.showModpackPicker = $0 }
                )) {
                    NXMModpackPickerSheet(importedMods: appState.pendingNXMMods)
                        .environment(appState)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Mods...") {
                    appState.sidebarSelection = .installedMods
                    appState.showImportPicker = true
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Refresh Mod List") {
                    appState.loadMods()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Mods") {
                Button("Launch Game") {
                    appState.launchGame()
                }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!appState.settings.isSMAPIInstalled)

                Button("Check for Updates") {
                    appState.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: .command)

                Divider()

                Button("Toggle Selected Mod") {
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

                Button("Show in Finder") {
                    if let mod = appState.selectedMod {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(appState.selectedMod == nil)
            }

            CommandGroup(before: .toolbar) {
                Button("Show All Mods") {
                    appState.filterMode = .all
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Show Enabled Only") {
                    appState.filterMode = .enabled
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show Disabled Only") {
                    appState.filterMode = .disabled
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .id(appState.settings.theme)
                .environment(appState)
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
                        Text("Select an item from the sidebar")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            if !appState.settings.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .background(WindowAccessor())
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
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
