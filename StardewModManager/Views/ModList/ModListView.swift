import SwiftUI

struct ModListView: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirmation = false
    @State private var modToDelete: Mod?
    @State private var dependencyWarning: DependencyWarning?
    @State private var pendingToggleMod: Mod?
    @State private var showDependencyAlert = false

    var body: some View {
        @Bindable var state = appState

        HSplitView {
            // Mod list
            VStack(spacing: 0) {
                // Filter bar
                ModFilterBar()
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search mods...", text: $state.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.bar)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.vertical, 8)

                if appState.isLoading {
                    ProgressView("Loading mods...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.filteredMods.isEmpty {
                    ContentUnavailableView(
                        "No Mods Found",
                        systemImage: "folder.badge.questionmark",
                        description: Text(appState.searchText.isEmpty ? "No mods installed" : "No mods match your search")
                    )
                } else {
                    List(appState.filteredMods, selection: $state.selectedModID) { mod in
                        ModRowView(
                            mod: mod,
                            onToggle: { handleToggle(mod) },
                            onDelete: {
                                modToDelete = mod
                                showDeleteConfirmation = true
                            }
                        )
                        .tag(mod.id)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 400)

            // Detail panel
            if let mod = appState.selectedMod {
                ModDetailView(mod: mod)
                    .frame(minWidth: 300, idealWidth: 350)
            } else {
                Text("Select a mod to view details")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 300, idealWidth: 350)
                    .frame(maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Delete Mod",
            isPresented: $showDeleteConfirmation,
            presenting: modToDelete
        ) { mod in
            Button("Delete \"\(mod.manifest.name)\"", role: .destructive) {
                appState.deleteMod(mod)
            }
        } message: { mod in
            Text("Are you sure you want to permanently delete \"\(mod.manifest.name)\"? This cannot be undone.")
        }
        .alert("Dependency Warning", isPresented: $showDependencyAlert, presenting: dependencyWarning) { _ in
            Button("Continue Anyway") {
                if let mod = pendingToggleMod {
                    if mod.isEnabled {
                        appState.performDisableMod(mod)
                    } else {
                        appState.performEnableMod(mod)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { warning in
            Text(warning.message)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    appState.loadMods()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh mod list")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleToggle(_ mod: Mod) {
        let warning = appState.toggleMod(mod)
        if let warning {
            dependencyWarning = warning
            pendingToggleMod = mod
            showDependencyAlert = true
        } else {
            if mod.isEnabled {
                appState.performDisableMod(mod)
            } else {
                appState.performEnableMod(mod)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                appState.importMods(from: urls)
            }
        }

        return true
    }
}
