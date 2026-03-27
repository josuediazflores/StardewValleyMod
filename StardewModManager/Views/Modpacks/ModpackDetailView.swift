import SwiftUI

struct ModpackDetailView: View {
    let modpack: Modpack
    @Environment(AppState.self) private var appState

    @State private var showDeleteConfirmation = false
    @State private var applyResultMessage: String?
    @State private var showApplyAlert = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(modpack.name)
                        .font(.stardew(size: 24))
                        .foregroundStyle(Color.textDark)

                    if !modpack.description.isEmpty {
                        Text(modpack.description)
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.textLight)
                    }
                }

                // Source badge
                HStack(spacing: 10) {
                    sourceBadge

                    if appState.activeModpackID == modpack.id {
                        Text("Active")
                            .font(.stardew(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stardewGreen.opacity(0.2))
                            .foregroundStyle(Color.stardewGreen)
                            .clipShape(Capsule())
                    }
                }

                // Dates
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Created:")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                        Text(Self.dateFormatter.string(from: modpack.createdAt))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textLight)
                    }
                    HStack(spacing: 6) {
                        Text("Updated:")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                        Text(Self.dateFormatter.string(from: modpack.updatedAt))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textLight)
                    }
                }

                Divider()
                    .overlay(Color.stardewDivider)

                // Apply button
                Button {
                    applyModpack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Apply Profile")
                            .font(.stardew(size: 18))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.stardewGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                // Export dropdown
                Menu {
                    Button("Export as JSON") {
                        exportModpack(asZIP: false)
                    }
                    Button("Export as ZIP") {
                        exportModpack(asZIP: true)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("Export")
                            .font(.stardew(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentGold)
                    .foregroundStyle(Color.textDark)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Divider()
                    .overlay(Color.stardewDivider)

                // Mod entries
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mods (\(modpack.entries.count))")
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)

                    ForEach(modpack.entries) { entry in
                        modEntryRow(entry)
                    }
                }

                Divider()
                    .overlay(Color.stardewDivider)

                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete Modpack")
                            .font(.stardew(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.stardewRed.opacity(0.15))
                    .foregroundStyle(Color.stardewRed)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(Color.parchment)
        .confirmationDialog(
            "Delete Modpack",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete \"\(modpack.name)\"", role: .destructive) {
                appState.deleteModpack(modpack)
            }
        } message: {
            Text("Are you sure you want to delete \"\(modpack.name)\"? This cannot be undone.")
        }
        .alert("Modpack Applied", isPresented: $showApplyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let msg = applyResultMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Source Badge

    @ViewBuilder
    private var sourceBadge: some View {
        let (label, color) = sourceInfo
        Text(label)
            .font(.stardew(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var sourceInfo: (String, Color) {
        switch modpack.source {
        case .manual:
            return ("Manual", Color.stardewPurple)
        case .nexusCollection:
            return ("Nexus Collection", Color.stardewOrange)
        case .imported:
            return ("Imported", Color.stardewBlue)
        case .externalURL:
            return ("External", Color.textMuted)
        }
    }

    // MARK: - Mod Entry Row

    @ViewBuilder
    private func modEntryRow(_ entry: ModpackEntry) -> some View {
        let status = entryStatus(entry)

        HStack(spacing: 10) {
            // Status indicator
            statusIcon(status)

            // Name + version
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.stardew(size: 15))
                    .foregroundStyle(Color.textDark)
                    .lineLimit(1)

                if let version = entry.version {
                    Text("v\(version)")
                        .font(.stardew(size: 12))
                        .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            // Download button for missing mods with Nexus ID
            if status == .missing, entry.nexusModID != nil {
                Button {
                    downloadMissingMod(entry)
                } label: {
                    Text("Download")
                        .font(.stardew(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.parchmentAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Status

    private enum EntryStatus {
        case installedEnabled
        case installedDisabled
        case missing
    }

    private func entryStatus(_ entry: ModpackEntry) -> EntryStatus {
        if let mod = appState.mods.first(where: { $0.manifest.uniqueID == entry.uniqueID }) {
            return mod.isEnabled ? .installedEnabled : .installedDisabled
        }
        return .missing
    }

    @ViewBuilder
    private func statusIcon(_ status: EntryStatus) -> some View {
        switch status {
        case .installedEnabled:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.stardewGreen)
                .font(.system(size: 14))
        case .installedDisabled:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(Color.stardewOrange)
                .font(.system(size: 14))
        case .missing:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.stardewRed)
                .font(.system(size: 14))
        }
    }

    // MARK: - Actions

    private func applyModpack() {
        appState.applyModpack(modpack)
        if let error = appState.modpackError {
            applyResultMessage = error
        } else {
            applyResultMessage = "Modpack \"\(modpack.name)\" applied successfully."
        }
        showApplyAlert = true
    }

    private func exportModpack(asZIP: Bool) {
        let panel = NSSavePanel()
        panel.title = "Export Modpack"
        panel.nameFieldStringValue = "\(modpack.name).\(asZIP ? "zip" : "json")"

        if panel.runModal() == .OK, let url = panel.url {
            appState.exportModpack(modpack, asZIP: asZIP, to: url)
        }
    }

    private func downloadMissingMod(_ entry: ModpackEntry) {
        guard let modId = entry.nexusModID, let fileId = entry.nexusFileID else { return }
        Task {
            await appState.downloadAndInstallMod(modId: modId, fileId: fileId)
        }
    }
}
