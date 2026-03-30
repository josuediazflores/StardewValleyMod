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
                // Play button + filter/search (when profile expanded)
                HStack(spacing: 12) {
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

                    if appState.expandedModpackID != nil {
                        StardewSegmentedPicker(
                            selection: $state.filterMode,
                            label: { $0.shortLabel }
                        )
                        .fixedSize()

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                            TextField("Search mods...", text: $state.searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textDark)
                                .frame(width: 130)
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
                    } else {
                        Spacer()
                    }
                }
                .padding(.bottom, 4)

                // Profiles header
                HStack(spacing: 8) {
                    Text("PROFILES")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                        .tracking(0.8)

                    VStack { Divider().overlay(Color.stardewDivider.opacity(0.5)) }

                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("New")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
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
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentGold)
                        .foregroundStyle(Color.textDark)
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 6)

                // Saved modpacks
                if appState.modpacks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textMuted.opacity(0.3))
                        Text("No saved profiles yet")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(.vertical, 24)
                } else {
                    ForEach(appState.filteredModpacks) { modpack in
                        ExpandableModpackCardView(
                            modpack: modpack,
                            isActive: appState.activeModpackID == modpack.id,
                            isExpanded: appState.expandedModpackID == modpack.id,
                            onApply: { applyModpack(modpack) },
                            onExportJSON: { showExportPanel(modpack: modpack, asZIP: false) },
                            onExportZIP: { showExportPanel(modpack: modpack, asZIP: true) },
                            onDelete: {
                                modpackToDelete = modpack
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(Color.parchment)
        .inspector(isPresented: $state.showInspector) {
            if let mod = appState.selectedMod {
                ModDetailView(mod: mod)
                    .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textMuted.opacity(0.3))
                    Text("Select a mod to view details")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.parchment)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(appState.modpacks.count) profiles \u{00B7} \(appState.mods.count) mods installed")
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Color.parchmentHeader
                    .overlay(alignment: .top) {
                        Color.stardewDivider.opacity(0.3).frame(height: 1)
                    }
            )
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
        .alert("Profile Loaded", isPresented: $showApplyAlert) {
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
            applyResultMessage = "Profile \"\(modpack.name)\" loaded successfully."
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
