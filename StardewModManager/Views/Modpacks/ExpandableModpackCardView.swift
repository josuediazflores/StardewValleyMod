import SwiftUI

struct ExpandableModpackCardView: View {
    @Environment(AppState.self) private var appState
    let modpack: Modpack
    let isActive: Bool
    let isExpanded: Bool
    let onApply: () -> Void
    let onExportJSON: () -> Void
    let onExportZIP: () -> Void
    let onShareSMM: () -> Void
    let onCopyClipboard: () -> Void
    let onDelete: () -> Void

    @State private var sortOrder = [KeyPathComparator(\Mod.manifest.name, order: .forward)]
    @State private var hoveredModID: String?
    @State private var isBatchMode = false
    @State private var selectedEntryIDs: Set<String> = []
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            cardHeader

            // Expanded content
            if isExpanded {
                Divider().overlay(Color.stardewDivider)

                if isBatchMode {
                    batchActionBar
                }

                savedModpackEntryList
            }
        }
        .background(Color.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.frameBorder, lineWidth: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.frameBorderDark, lineWidth: 1)
                .padding(2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                appState.expandedModpackID = modpack.id
            }
        }
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack(spacing: 10) {
            // Expand/collapse chevron
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        appState.expandedModpackID = nil
                    } else {
                        appState.expandedModpackID = modpack.id
                    }
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .onChange(of: isExpanded) { _, expanded in
                if !expanded { searchText = "" }
            }

            // Name
            Text(modpack.name)
                .font(.stardew(size: 18))
                .foregroundStyle(Color.textDark)
                .lineLimit(1)

            // Badge
            if isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.stardewGreen)
                        .frame(width: 6, height: 6)
                    Text(L.s("modpack_active"))
                        .font(.stardew(size: 12))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.stardewGreen.opacity(0.15))
                .foregroundStyle(Color.stardewGreen)
                .clipShape(Capsule())
            }

            sourceBadge

            let enabledCount = modpack.entries.filter(\.isEnabled).count
            Text(enabledCount == modpack.entries.count
                 ? L.s("modpack_mods_count", modpack.entries.count)
                 : "\(enabledCount)/\(modpack.entries.count) mods")
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)

            if isExpanded {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted)
                    TextField(L.s("modpack_search_mods"), text: $searchText)
                        .font(.stardew(size: 14))
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
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
                .frame(maxWidth: 200)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.frameBorder, lineWidth: 1)
                        )
                )
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                Button {
                    onApply()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(L.s("modpack_load_profile"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.stardewGreen)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    isBatchMode = true
                    selectedEntryIDs.removeAll()
                } label: {
                    Label(L.s("modpack_select"), systemImage: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)

                Menu {
                    Section(L.s("modpack_share")) {
                        Button(L.s("modpack_share_smm")) { onShareSMM() }
                        Button(L.s("modpack_copy_clipboard")) { onCopyClipboard() }
                    }
                    Section(L.s("common_export")) {
                        Button(L.s("modpack_export_json")) { onExportJSON() }
                        Button(L.s("modpack_export_zip")) { onExportZIP() }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .padding(4)
                        .foregroundStyle(Color.textLight)
                }

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .padding(4)
                        .foregroundStyle(Color.stardewRed)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isExpanded ? Color.parchmentHeader : Color.parchmentAlt)
    }

    // MARK: - Saved Modpack Entry List

    @ViewBuilder
    private var savedModpackEntryList: some View {
        let allEntries = appState.filteredEntriesForModpack(modpack)
        let entries = searchText.isEmpty ? allEntries : allEntries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let installedIDs = Set(appState.mods.map(\.id))

        if entries.isEmpty {
            Text(L.s("modpack_no_mods"))
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        let isInstalled = installedIDs.contains(entry.uniqueID)

                        HStack(spacing: 8) {
                            if isBatchMode {
                                Image(systemName: selectedEntryIDs.contains(entry.uniqueID) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedEntryIDs.contains(entry.uniqueID) ? Color.accentGold : Color.textMuted)
                            }

                            StardewIcon(type: .gear, size: 14)
                                .opacity(isInstalled ? 1 : 0.3)

                            Text(entry.name)
                                .font(.stardew(size: 15))
                                .foregroundStyle(isInstalled ? Color.textDark : Color.textMuted)
                                .lineLimit(1)

                            if let version = entry.version {
                                Text(version)
                                    .font(.stardew(size: 13))
                                    .foregroundStyle(Color.textLight)
                            }

                            Spacer()

                            if !isInstalled {
                                Text(L.s("modpack_missing"))
                                    .font(.stardew(size: 12))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.stardewRed.opacity(0.15))
                                    .foregroundStyle(Color.stardewRed)
                                    .clipShape(Capsule())
                            } else {
                                Toggle("", isOn: Binding(
                                    get: { entry.isEnabled },
                                    set: { _ in
                                        appState.toggleModpackEntry(modpackID: modpack.id, entryID: entry.uniqueID)
                                    }
                                ))
                                .toggleStyle(StardewToggleStyle())
                                .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isBatchMode {
                                if selectedEntryIDs.contains(entry.uniqueID) {
                                    selectedEntryIDs.remove(entry.uniqueID)
                                } else {
                                    selectedEntryIDs.insert(entry.uniqueID)
                                }
                            }
                        }
                        .contextMenu {
                            Button(entry.isEnabled ? L.s("modpack_disable") : L.s("modpack_enable")) {
                                appState.toggleModpackEntry(modpackID: modpack.id, entryID: entry.uniqueID)
                            }
                            Divider()
                            Button(L.s("modpack_remove"), role: .destructive) {
                                appState.removeModpackEntry(modpackID: modpack.id, entryID: entry.uniqueID)
                            }
                        }

                        if index < entries.count - 1 {
                            Color.stardewDivider.opacity(0.2).frame(height: 1)
                                .padding(.leading, 36)
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(entries.count) * 38, 500))
            .background(Color.parchment)
        }
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: 10) {
            Text(L.s("modpack_selected_count", selectedEntryIDs.count))
                .font(.stardew(size: 13))
                .foregroundStyle(Color.textDark)

            Spacer()

            Button {
                let allIDs = Set(modpack.entries.map(\.uniqueID))
                if selectedEntryIDs == allIDs {
                    selectedEntryIDs.removeAll()
                } else {
                    selectedEntryIDs = allIDs
                }
            } label: {
                Text(selectedEntryIDs.count == modpack.entries.count ? L.s("modpack_deselect_all") : L.s("modpack_select_all"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentGold)
            }
            .buttonStyle(.plain)

            Button {
                appState.batchToggleModpackEntries(modpackID: modpack.id, entryIDs: selectedEntryIDs, enabled: true)
                isBatchMode = false
                selectedEntryIDs.removeAll()
            } label: {
                Text(L.s("modpack_enable_all"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.stardewGreen)
            }
            .buttonStyle(.plain)
            .disabled(selectedEntryIDs.isEmpty)

            Button {
                appState.batchToggleModpackEntries(modpackID: modpack.id, entryIDs: selectedEntryIDs, enabled: false)
                isBatchMode = false
                selectedEntryIDs.removeAll()
            } label: {
                Text(L.s("modpack_disable_all"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(selectedEntryIDs.isEmpty)

            Button {
                appState.batchRemoveModpackEntries(modpackID: modpack.id, entryIDs: selectedEntryIDs)
                isBatchMode = false
                selectedEntryIDs.removeAll()
            } label: {
                Text(L.s("modpack_remove_selected"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.stardewRed)
            }
            .buttonStyle(.plain)
            .disabled(selectedEntryIDs.isEmpty)

            Button {
                isBatchMode = false
                selectedEntryIDs.removeAll()
            } label: {
                Text(L.s("common_cancel"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textDark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.parchmentAlt)
    }

    // MARK: - Helpers

    private func toggleMod(_ mod: Mod) {
        if mod.isEnabled {
            appState.performDisableMod(mod)
        } else {
            appState.performEnableMod(mod)
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let (label, color) = sourceInfo
        Text(label)
            .font(.stardew(size: 12))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var sourceInfo: (String, Color) {
        switch modpack.source {
        case .manual:
            return (L.s("modpack_manual"), Color.stardewPurple)
        case .nexusCollection:
            return (L.s("modpack_nexus_collection"), Color.stardewOrange)
        case .imported:
            return (L.s("modpack_imported"), Color.stardewBlue)
        case .externalURL:
            return (L.s("modpack_external"), Color.textMuted)
        case .currentProfile:
            return (L.s("modpack_live"), Color.stardewGreen)
        }
    }
}

// MARK: - Shared Cell Views

struct ModNameCell: View {
    let mod: Mod

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(mod.modType == .codeMod ? Color.stardewPurple : Color.stardewOrange)
                .frame(width: 8, height: 8)

            Text(mod.manifest.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textDark)
                .lineLimit(1)

            if mod.isBuiltIn {
                Text(L.s("row_built_in"))
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.stardewBlue.opacity(0.15))
                    .foregroundStyle(Color.stardewBlue)
                    .clipShape(Capsule())
            }
        }
        .opacity(mod.isEnabled ? 1 : 0.5)
    }
}

struct ModTypeBadge: View {
    let mod: Mod

    var body: some View {
        let color: Color = mod.modType == .codeMod ? .stardewPurple : .stardewOrange
        Text(mod.modType.displayName)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .opacity(mod.isEnabled ? 1 : 0.5)
    }
}

private struct VersionCell: View {
    let mod: Mod
    let updateInfo: ModUpdateInfo?

    var body: some View {
        HStack(spacing: 4) {
            Text(mod.manifest.version)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.textMuted)
                .opacity(mod.isEnabled ? 1 : 0.5)

            if let update = updateInfo {
                Button {
                    if let urlString = update.updateURL, let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text(update.newVersion)
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.stardewBlue.opacity(0.12))
                    .foregroundStyle(Color.stardewBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(L.s("row_update_help"))
            }
        }
    }
}
