import SwiftUI

struct ModpackListView: View {
    @Environment(AppState.self) private var appState

    @State private var showCreateSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var modpackToDelete: Modpack?
    @State private var applyResultMessage: String?
    @State private var showApplyAlert = false
    @State private var exportModpack: Modpack?
    @State private var exportAsZIP = false

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Modpack")
                            .font(.stardew(size: 16))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.stardewGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Menu {
                    Button("From File...") {
                        importFromFile()
                    }
                    Button("From URL...") {
                        showImportSheet = true
                    }
                    Button("From Nexus Collection...") {
                        showImportSheet = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                            .font(.stardew(size: 16))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentGold)
                    .foregroundStyle(Color.textDark)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.parchmentHeader)

            Divider()
                .overlay(Color.stardewDivider)

            // Content
            if appState.modpacks.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Modpacks")
                            .font(.stardew(size: 22))
                            .foregroundStyle(Color.textDark)
                    } icon: {
                        StardewIcon(type: .chest, size: 48)
                    }
                } description: {
                    Text("Create a modpack to save your current mod configuration, or import one from a file or URL.")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textLight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.modpacks) { modpack in
                            ModpackCardView(
                                modpack: modpack,
                                isActive: appState.activeModpackID == modpack.id,
                                isSelected: appState.selectedModpackID == modpack.id,
                                onSelect: {
                                    appState.selectedModpackID = modpack.id
                                },
                                onApply: {
                                    applyModpack(modpack)
                                },
                                onExportJSON: {
                                    exportModpack = modpack
                                    exportAsZIP = false
                                    showExportPanel(modpack: modpack, asZIP: false)
                                },
                                onExportZIP: {
                                    exportModpack = modpack
                                    exportAsZIP = true
                                    showExportPanel(modpack: modpack, asZIP: true)
                                },
                                onDelete: {
                                    modpackToDelete = modpack
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.parchment)
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
}

// MARK: - Modpack Card

private struct ModpackCardView: View {
    let modpack: Modpack
    let isActive: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onApply: () -> Void
    let onExportJSON: () -> Void
    let onExportZIP: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name + active indicator
            HStack {
                Text(modpack.name)
                    .font(.stardew(size: 18))
                    .foregroundStyle(Color.textDark)
                    .lineLimit(1)

                if isActive {
                    Text("Active")
                        .font(.stardew(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.stardewGreen.opacity(0.2))
                        .foregroundStyle(Color.stardewGreen)
                        .clipShape(Capsule())
                }

                Spacer()

                sourceBadge
            }

            // Description
            if !modpack.description.isEmpty {
                Text(modpack.description)
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textLight)
                    .lineLimit(2)
            }

            // Mod count
            HStack(spacing: 16) {
                Text("\(modpack.entries.count) mods")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onApply()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Apply")
                                .font(.stardew(size: 14))
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
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text("Export")
                                .font(.stardew(size: 14))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentGold)
                        .foregroundStyle(Color.textDark)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .padding(6)
                            .foregroundStyle(Color.stardewRed)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(isSelected ? Color.parchmentAlt : Color.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.stardewGreen : Color.accentGold.opacity(0.4), lineWidth: isActive ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
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
            return ("Nexus Collection", Color.stardewOrange)
        case .imported:
            return ("Imported", Color.stardewBlue)
        case .externalURL:
            return ("External", Color.textMuted)
        }
    }
}
