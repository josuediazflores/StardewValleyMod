import SwiftUI

struct ModListView: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirmation = false
    @State private var modToDelete: Mod?
    @State private var dependencyWarning: DependencyWarning?
    @State private var pendingToggleMod: Mod?
    @State private var showDependencyAlert = false
    @State private var sortOrder = [KeyPathComparator(\Mod.manifest.name, order: .forward)]

    var body: some View {
        @Bindable var state = appState

        Group {
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
                modTable
            }
        }
        .inspector(isPresented: $state.showInspector) {
            if let mod = appState.selectedMod {
                ModDetailView(mod: mod)
                    .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
            } else {
                Text("Select a mod to view details")
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(appState.filteredMods.count) mods \u{00B7} \(appState.enabledCount) enabled \u{00B7} \(appState.disabledCount) disabled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Table

    @ViewBuilder
    private var modTable: some View {
        @Bindable var state = appState

        Table(appState.filteredMods, selection: $state.selectedModID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.manifest.name) { mod in
                ModNameCell(mod: mod)
            }

            TableColumn("Author", value: \.manifest.author) { (mod: Mod) in
                Text(mod.manifest.author)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(mod.isEnabled ? 1 : 0.6)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Version", value: \.manifest.version) { (mod: Mod) in
                Text(mod.manifest.version)
                    .foregroundStyle(.secondary)
                    .opacity(mod.isEnabled ? 1 : 0.6)
            }
            .width(80)

            TableColumn("Type") { (mod: Mod) in
                ModTypeBadge(mod: mod)
            }
            .width(100)

            TableColumn("Status") { (mod: Mod) in
                if !mod.isBuiltIn {
                    Toggle("", isOn: Binding(
                        get: { mod.isEnabled },
                        set: { _ in handleToggle(mod) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
            }
            .width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selectedIDs in
            contextMenuContent(for: selectedIDs)
        }
        .onChange(of: sortOrder) { _, newOrder in
            appState.sortMods(using: newOrder)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(for selectedIDs: Set<String>) -> some View {
        if let modID = selectedIDs.first,
           let mod = appState.mods.first(where: { $0.id == modID }) {
            if !mod.isBuiltIn {
                Button(mod.isEnabled ? "Disable Mod" : "Enable Mod") {
                    handleToggle(mod)
                }
                Divider()
            }

            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
            }

            if let nexusID = mod.nexusModID {
                Button("View on Nexus Mods") {
                    appState.openNexusModPage(modId: nexusID)
                }
            }

            Button("Copy Unique ID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(mod.manifest.uniqueID, forType: .string)
            }

            if !mod.isBuiltIn {
                Divider()
                Button("Delete Mod...", role: .destructive) {
                    modToDelete = mod
                    showDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

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

// MARK: - Cell Views

private struct ModNameCell: View {
    let mod: Mod

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mod.modType == .codeMod ? "gearshape.fill" : "doc.fill")
                .foregroundStyle(mod.modType == .codeMod ? .purple : .orange)
                .frame(width: 20)
            Text(mod.manifest.name)
                .fontWeight(.medium)
                .lineLimit(1)
            if mod.isBuiltIn {
                Text("Built-in")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .opacity(mod.isEnabled ? 1 : 0.6)
    }
}

private struct ModTypeBadge: View {
    let mod: Mod

    var body: some View {
        let color: Color = mod.modType == .codeMod ? .purple : .orange
        Text(mod.modType.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .opacity(mod.isEnabled ? 1 : 0.6)
    }
}
