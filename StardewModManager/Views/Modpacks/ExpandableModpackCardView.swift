import SwiftUI

struct ExpandableModpackCardView: View {
    @Environment(AppState.self) private var appState
    let modpack: Modpack
    let isCurrentProfile: Bool
    let isExpanded: Bool
    let onApply: () -> Void
    let onExportJSON: () -> Void
    let onExportZIP: () -> Void
    let onDelete: () -> Void
    let onSaveAsModpack: () -> Void

    @State private var sortOrder = [KeyPathComparator(\Mod.manifest.name, order: .forward)]
    @State private var hoveredModID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            cardHeader

            // Expanded content
            if isExpanded {
                Divider().overlay(Color.stardewDivider)

                if isCurrentProfile {
                    currentProfileTable
                } else {
                    savedModpackEntryList
                }
            }
        }
        .background(Color.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isCurrentProfile && isExpanded ? Color.stardewGreen.opacity(0.5) :
                    isExpanded ? Color.cardBorder : Color.cardBorder.opacity(0.3),
                    lineWidth: isExpanded ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(isExpanded ? 0.08 : 0.03), radius: isExpanded ? 8 : 3, y: isExpanded ? 3 : 1)
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
            if isCurrentProfile {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.stardewGreen)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.stardew(size: 12))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.stardewGreen.opacity(0.15))
                .foregroundStyle(Color.stardewGreen)
                .clipShape(Capsule())
            } else {
                sourceBadge
            }

            // Mod count
            if isCurrentProfile {
                let enabled = modpack.entries.filter(\.isEnabled).count
                Text("\(enabled) mods")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
            } else {
                Text("\(modpack.entries.count) mods")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            // Action buttons
            if isCurrentProfile {
                Button {
                    onSaveAsModpack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text("Save as Pack")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentGold)
                    .foregroundStyle(Color.textDark)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        onApply()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Load Profile")
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
                        Button("Export as JSON") { onExportJSON() }
                        Button("Export as ZIP") { onExportZIP() }
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isExpanded ? Color.parchmentHeader.opacity(0.4) : Color.clear)
    }

    // MARK: - Current Profile Table

    @ViewBuilder
    private var currentProfileTable: some View {
        let mods = appState.filteredMods

        if mods.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textMuted.opacity(0.4))
                Text("No mods match the current filter")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // Left: type dot + name on line 1, author on line 2
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(mod.modType == .codeMod ? Color.stardewPurple : Color.stardewOrange)
                                            .frame(width: 7, height: 7)

                                        Text(mod.manifest.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.textDark)
                                            .lineLimit(1)

                                        if mod.isBuiltIn {
                                            Text("Built-in")
                                                .font(.system(size: 9, weight: .semibold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.stardewBlue.opacity(0.12))
                                                .foregroundStyle(Color.stardewBlue)
                                                .clipShape(Capsule())
                                        }

                                        if let update = appState.modUpdates[mod.id] {
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
                                            .help("Update available")
                                        }
                                    }

                                    Text(mod.manifest.author)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textMuted)
                                        .lineLimit(1)
                                        .padding(.leading, 15)
                                }

                                Spacer(minLength: 12)

                                // Right: version + type badge
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(mod.manifest.version)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.textLight)

                                    ModTypeBadge(mod: mod)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .opacity(mod.isEnabled ? 1 : 0.5)
                            .background(
                                Group {
                                    if appState.selectedModID == mod.id {
                                        Color.rowSelected
                                    } else if hoveredModID == mod.id {
                                        Color.rowHover
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .overlay(alignment: .leading) {
                                if appState.selectedModID == mod.id {
                                    Color.accentGold
                                        .frame(width: 3)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.selectedModID = mod.id
                            }
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    hoveredModID = hovering ? mod.id : nil
                                }
                            }
                            .contextMenu {
                                if !mod.isBuiltIn {
                                    Button(mod.isEnabled ? "Disable Mod" : "Enable Mod") {
                                        toggleMod(mod)
                                    }
                                    Divider()
                                }
                                Button("Show in Finder") {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
                                }
                                Button("Copy Unique ID") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(mod.manifest.uniqueID, forType: .string)
                                }
                                if !mod.isBuiltIn {
                                    Divider()
                                    Button("Delete Mod...", role: .destructive) {
                                        appState.deleteMod(mod)
                                    }
                                }
                            }

                            // Indented divider
                            if index < mods.count - 1 {
                                Color.stardewDivider.opacity(0.2)
                                    .frame(height: 1)
                                    .padding(.leading, 31)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 500)
        }
    }

    // MARK: - Saved Modpack Entry List

    @ViewBuilder
    private var savedModpackEntryList: some View {
        let entries = appState.filteredEntriesForModpack(modpack)
        let installedIDs = Set(appState.mods.map(\.id))

        if entries.isEmpty {
            Text("No mods in this modpack")
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            List(entries) { entry in
                HStack(spacing: 8) {
                    // Install status
                    let isInstalled = installedIDs.contains(entry.uniqueID)

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
                        Text("Missing")
                            .font(.stardew(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stardewRed.opacity(0.15))
                            .foregroundStyle(Color.stardewRed)
                            .clipShape(Capsule())
                    } else {
                        Text(entry.isEnabled ? "Enabled" : "Disabled")
                            .font(.stardew(size: 12))
                            .foregroundStyle(entry.isEnabled ? Color.stardewGreen : Color.textMuted)
                    }

                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button(entry.isEnabled ? "Disable" : "Enable") {
                        appState.toggleModpackEntry(modpackID: modpack.id, entryID: entry.uniqueID)
                    }
                    Divider()
                    Button("Remove from Modpack", role: .destructive) {
                        appState.removeModpackEntry(modpackID: modpack.id, entryID: entry.uniqueID)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.parchment)
            .frame(maxHeight: 450)
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
            return ("Manual", Color.stardewPurple)
        case .nexusCollection:
            return ("Nexus", Color.stardewOrange)
        case .imported:
            return ("Imported", Color.stardewBlue)
        case .externalURL:
            return ("External", Color.textMuted)
        case .currentProfile:
            return ("Live", Color.stardewGreen)
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
                Text("Built-in")
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
        Text(mod.modType.rawValue)
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
                .help("Update available")
            }
        }
    }
}
