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

        VStack(spacing: 0) {
            // Custom header bar (replaces native toolbar entirely)
            HStack(spacing: 12) {
                // Play button
                Button {
                    appState.launchGame()
                } label: {
                    HStack(spacing: 8) {
                        JunimoIcon(name: appState.selectedJunimoName, size: 24)
                            .frame(width: 24, height: 24)
                        Text("Play")
                            .font(.stardew(size: 24))
                            .foregroundStyle(.white)
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

                Spacer()

                // Filter picker (when viewing mods)
                if appState.expandedModpackID != nil || appState.sidebarSelection == .installedMods {
                    StardewSegmentedPicker(
                        selection: $state.filterMode,
                        label: { $0.shortLabel }
                    )
                    .fixedSize()
                }

                Spacer()

                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted)
                    TextField(
                        appState.expandedModpackID != nil ? "Search mods..." : "Search modpacks...",
                        text: $state.searchText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textDark)
                    .frame(width: 160)
                    if !appState.searchText.isEmpty {
                        Button {
                            appState.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.parchmentAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.frameBorder.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.parchmentHeader)

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
