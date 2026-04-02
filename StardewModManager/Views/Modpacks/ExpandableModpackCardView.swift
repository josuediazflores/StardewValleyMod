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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            cardHeader

            // Expanded content
            if isExpanded {
                Divider().overlay(Color.stardewDivider)

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

            Text(L.s("modpack_mods_count", modpack.entries.count))
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)

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
        let entries = appState.filteredEntriesForModpack(modpack)
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
                    .background(Color.stardewOrange.opacity(0.12))
                    .foregroundStyle(Color.stardewOrange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(L.s("row_update_help"))
            }
        }
    }
}
