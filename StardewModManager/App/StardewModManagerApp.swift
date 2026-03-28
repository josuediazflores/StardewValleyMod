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
        .windowToolbarStyle(.unified)
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

        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
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
        .toolbar(removing: .sidebarToggle)
        .preferredColorScheme(.light)
        .toolbarBackground(Color.parchment, for: .windowToolbar)
        .background(WindowAccessor())
        .searchable(text: $state.searchText, placement: .toolbar, prompt: appState.expandedModpackID != nil ? "Search mods..." : "Search modpacks...")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.launchGame()
                } label: {
                    HStack(spacing: 8) {
                        JunimoIcon(name: appState.selectedJunimoName, size: 24)
                            .frame(width: 24, height: 24)
                        Text("Play")
                            .font(.stardew(size: 24))
                            .foregroundStyle(Color.parchment)
                            .frame(height: 24)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.stardewGreen, .stardewGreenDark], startPoint: .top, endPoint: .bottom))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(hex: 0x3E5C22), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(PlayButtonStyle())
                .disabled(!appState.settings.isSMAPIInstalled)
                .help("Launch Stardew Valley with SMAPI")
                .layoutPriority(1)
            }

            ToolbarItem(placement: .principal) {
                if appState.expandedModpackID != nil {
                    StardewSegmentedPicker(
                        selection: $state.filterMode,
                        label: { $0.shortLabel }
                    )
                    .frame(minWidth: 200, idealWidth: 400, maxWidth: 500)
                    .layoutPriority(-1)
                }
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
        window.backgroundColor = NSColor(Color.parchment)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.isVisible = true
        window.toolbar?.showsBaselineSeparator = false
        // Remove the sidebar toggle button from toolbar
        if let toolbar = window.toolbar {
            toolbar.items.forEach { item in
                if item.itemIdentifier.rawValue.contains("sidebarTrackingSeparator") ||
                   item.itemIdentifier.rawValue.contains("toggleSidebar") ||
                   item.itemIdentifier == .toggleSidebar {
                    item.isEnabled = false
                    item.view?.isHidden = true
                }
            }
        }
        window.minSize = NSSize(width: 700, height: 450)
        window.collectionBehavior.insert(.fullScreenPrimary)
        // Hide the sidebar toggle button
        if let splitView = window.contentView?.subviews.first(where: { $0 is NSSplitView }) as? NSSplitView {
            splitView.dividerStyle = .thin
        }
        // Remove separator between titlebar and detail pane; keep sidebar inset
        if let svc = findSplitViewController(in: window.contentViewController) {
            for (index, item) in svc.splitViewItems.enumerated() {
                item.titlebarSeparatorStyle = index == 0 ? .line : .none
            }
        }
    }

    private func findSplitViewController(in viewController: NSViewController?) -> NSSplitViewController? {
        if let svc = viewController as? NSSplitViewController {
            return svc
        }
        for child in viewController?.children ?? [] {
            if let found = findSplitViewController(in: child) {
                return found
            }
        }
        return nil
    }
}
