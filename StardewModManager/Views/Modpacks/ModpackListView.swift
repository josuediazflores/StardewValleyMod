import SwiftUI

struct ModpackListView: View {
    @Environment(AppState.self) private var appState

    @State private var showCreateSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var modpackToDelete: Modpack?
    @State private var applyResultMessage: String?
    @State private var showApplyAlert = false

    var body: some View {
        @Bindable var state = appState

        ScrollView {
            LazyVStack(spacing: 10) {
                // Current Profile
                ExpandableModpackCardView(
                    modpack: appState.currentProfileModpack,
                    isCurrentProfile: true,
                    isExpanded: appState.expandedModpackID == AppState.currentProfileID,
                    onApply: {},
                    onExportJSON: {},
                    onExportZIP: {},
                    onDelete: {},
                    onSaveAsModpack: { showCreateSheet = true }
                )

                // Saved Profiles header
                HStack(spacing: 8) {
                    Text("Saved Profiles")
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)

                    VStack { Divider().overlay(Color.stardewDivider) }

                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.stardew(size: 13))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button("From File...") { importFromFile() }
                        Button("From URL...") { showImportSheet = true }
                        Button("From Nexus Collection...") { showImportSheet = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                            Text("Import")
                                .font(.stardew(size: 13))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentGold)
                        .foregroundStyle(Color.textDark)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(.vertical, 4)

                // Saved modpacks
                if appState.modpacks.isEmpty {
                    Text("No saved profiles yet")
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)
                        .padding(.vertical, 20)
                } else {
                    ForEach(appState.filteredModpacks) { modpack in
                        ExpandableModpackCardView(
                            modpack: modpack,
                            isCurrentProfile: false,
                            isExpanded: appState.expandedModpackID == modpack.id,
                            onApply: { applyModpack(modpack) },
                            onExportJSON: { showExportPanel(modpack: modpack, asZIP: false) },
                            onExportZIP: { showExportPanel(modpack: modpack, asZIP: true) },
                            onDelete: {
                                modpackToDelete = modpack
                                showDeleteConfirmation = true
                            },
                            onSaveAsModpack: {}
                        )
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(Color.parchment)
        .inspector(isPresented: $state.showInspector) {
            if appState.expandedModpackID == AppState.currentProfileID,
               let mod = appState.selectedMod {
                ModDetailView(mod: mod)
                    .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
            } else {
                Text("Select a mod to view details")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.parchment)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                if appState.expandedModpackID == AppState.currentProfileID {
                    Text("\(appState.filteredMods.count) mods \u{00B7} \(appState.enabledCount) enabled \u{00B7} \(appState.disabledCount) disabled")
                } else {
                    Text("\(appState.modpacks.count + 1) profiles \u{00B7} \(appState.mods.count) mods installed")
                }
                Spacer()
            }
            .font(.stardew(size: 14))
            .foregroundStyle(Color.textLight)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.parchmentHeader)
        }
        .sheet(isPresented: $showCreateSheet) {
            ModpackCreateSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showImportSheet) {
            ModpackImportSheet()
                .environment(appState)
        }
        .confirmationDialog(
            "Delete Modpack",
            isPresented: $showDeleteConfirmation,
            presenting: modpackToDelete
        ) { modpack in
            Button("Delete \"\(modpack.name)\"", role: .destructive) {
                appState.deleteModpack(modpack)
            }
        } message: { modpack in
            Text("Are you sure you want to delete \"\(modpack.name)\"? This cannot be undone.")
        }
        .alert("Modpack Applied", isPresented: $showApplyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = applyResultMessage {
                Text(msg)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .onChange(of: appState.expandedModpackID) { _, _ in
            appState.searchText = ""
            appState.filterMode = .all
        }
    }

    // MARK: - Actions

    private func applyModpack(_ modpack: Modpack) {
        appState.applyModpack(modpack)
        if let error = appState.modpackError {
            applyResultMessage = error
        } else {
            applyResultMessage = "Modpack \"\(modpack.name)\" applied successfully."
        }
        showApplyAlert = true
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Modpack"
        panel.allowedContentTypes = [.json, .zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.importModpackFromFile(url: url)
        }
    }

    private func showExportPanel(modpack: Modpack, asZIP: Bool) {
        let panel = NSSavePanel()
        panel.title = "Export Modpack"
        panel.nameFieldStringValue = "\(modpack.name).\(asZIP ? "zip" : "json")"

        if panel.runModal() == .OK, let url = panel.url {
            appState.exportModpack(modpack, asZIP: asZIP, to: url)
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
