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
            case .myMods:
                ModListView()
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
        .searchable(text: $state.searchText, placement: .toolbar, prompt: "Search mods...")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.launchGame()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .tint(.stardewGreen)
                .disabled(!appState.settings.isSMAPIInstalled)
                .help("Launch Stardew Valley with SMAPI")
            }

            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: $state.filterMode) {
                    ForEach(ModFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)
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
