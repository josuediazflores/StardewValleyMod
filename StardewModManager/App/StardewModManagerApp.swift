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
                .environment(appState)
                .onAppear {
                    appState.loadMods()
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
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Mods...") {
                    appState.sidebarSelection = .importMods
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
                Button("Toggle Inspector") {
                    appState.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Divider()

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
                .environment(appState)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView()
        } detail: {
            switch appState.sidebarSelection {
            case .modpacks:
                ModpackListView()
            case .browseNexus:
                NexusBrowseView()
            case .importMods:
                ImportModView()
            case nil:
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("")
        .preferredColorScheme(.light)
        .toolbarBackground(Color.parchmentHeader, for: .windowToolbar)
        .background(WindowAccessor())
        .searchable(text: $state.searchText, placement: .toolbar, prompt: appState.expandedModpackID != nil ? "Search mods..." : "Search modpacks...")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.launchGame()
                } label: {
                    HStack(spacing: 10) {
                        JunimoIcon(name: appState.selectedJunimoName, size: 36)
                        Text("Play")
                            .font(.stardew(size: 24))
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.stardewGreen.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.stardewGreen, lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!appState.settings.isSMAPIInstalled)
                .help("Launch Stardew Valley with SMAPI")
                .layoutPriority(1)
            }

            ToolbarItem(placement: .principal) {
                if appState.expandedModpackID != nil {
                    StardewSegmentedPicker(
                        selection: $state.filterMode,
                        label: { $0.rawValue }
                    )
                    .frame(minWidth: 200, idealWidth: 400, maxWidth: 500)
                    .layoutPriority(-1)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
                .help("Toggle Inspector")
            }
        }
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
        window.toolbar?.isVisible = true
        window.minSize = NSSize(width: 700, height: 450)
        window.collectionBehavior.insert(.fullScreenPrimary)
        // Keep toolbar visible in full screen
        let accessor = NSTitlebarAccessoryViewController()
        accessor.layoutAttribute = .bottom
        accessor.fullScreenMinHeight = 0
        if window.titlebarAccessoryViewControllers.isEmpty {
            window.addTitlebarAccessoryViewController(accessor)
        }
    }
}
