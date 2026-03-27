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
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isCurrentProfile && isExpanded ? Color.stardewGreen :
                    isExpanded ? Color.accentGold : Color.accentGold.opacity(0.4),
                    lineWidth: isExpanded ? 2 : 1
                )
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
            Text("\(modpack.entries.count) mods")
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)

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
                            .font(.stardew(size: 13))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentGold)
                    .foregroundStyle(Color.textDark)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
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
                            Text("Apply")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isExpanded ? Color.parchmentHeader.opacity(0.5) : Color.clear)
    }

    // MARK: - Current Profile Table

    @ViewBuilder
    private var currentProfileTable: some View {
        let mods = appState.filteredMods

        if mods.isEmpty {
            Text("No mods match the current filter")
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            // Header row
            HStack(spacing: 0) {
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Author")
                    .frame(width: 140, alignment: .leading)
                Text("Version")
                    .frame(width: 80, alignment: .leading)
                Text("Type")
                    .frame(width: 100, alignment: .leading)
                Text("Status")
                    .frame(width: 60, alignment: .center)
            }
            .font(.stardew(size: 13))
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.parchmentHeader)

            // Mod rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(mods) { mod in
                        HStack(spacing: 0) {
                            // Name
                            HStack(spacing: 8) {
                                ModNameCell(mod: mod)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Author
                            Text(mod.manifest.author)
                                .font(.stardew(size: 15))
                                .foregroundStyle(Color.textLight)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                                .opacity(mod.isEnabled ? 1 : 0.55)

                            // Version
                            VersionCell(mod: mod, updateInfo: appState.modUpdates[mod.id])
                                .frame(width: 80, alignment: .leading)

                            // Type
                            ModTypeBadge(mod: mod)
                                .frame(width: 100, alignment: .leading)

                        }
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            appState.selectedModID == mod.id
                                ? Color.accentGold.opacity(0.2)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectedModID = mod.id
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

                        if mod.id != mods.last?.id {
                            Divider().overlay(Color.stardewDivider.opacity(0.3))
                        }
                    }
                }
            }
            .frame(height: min(CGFloat(mods.count) * 35, 450))
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
        HStack(spacing: 8) {
            if mod.modType == .codeMod,
               let iridiumURL = Bundle.module.url(forResource: "Iridium_Bar", withExtension: "png"),
               let iridiumImg = NSImage(contentsOf: iridiumURL) {
                Image(nsImage: iridiumImg)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 16, height: 16)
            } else if let url = Bundle.module.url(forResource: "Secret_Note", withExtension: "png"),
                      let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 16, height: 16)
            } else {
                StardewIcon(type: .scroll, size: 16)
            }
            Text(mod.manifest.name)
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textDark)
                .lineLimit(1)
            if mod.isBuiltIn {
                HStack(spacing: 3) {
                    StardewIcon(type: .star, size: 10)
                    Text("Built-in")
                        .font(.stardew(size: 12))
                        .foregroundStyle(Color(red: 0.1, green: 0.29, blue: 0.36))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.stardewBlue.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .opacity(mod.isEnabled ? 1 : 0.55)
    }
}

struct ModTypeBadge: View {
    let mod: Mod

    var body: some View {
        let color: Color = mod.modType == .codeMod ? .stardewPurple : .stardewOrange
        Text(mod.modType.rawValue)
            .font(.stardew(size: 13))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .opacity(mod.isEnabled ? 1 : 0.55)
    }
}

private struct VersionCell: View {
    let mod: Mod
    let updateInfo: ModUpdateInfo?

    var body: some View {
        HStack(spacing: 4) {
            Text(mod.manifest.version)
                .font(.stardew(size: 15))
                .foregroundStyle(Color.textLight)
                .opacity(mod.isEnabled ? 1 : 0.55)

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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.stardewOrange.opacity(0.15))
                    .foregroundStyle(Color.stardewOrange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Update available")
            }
        }
    }
}
