import SwiftUI

struct ModDetailView: View {
    let mod: Mod
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(mod.manifest.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textDark)

                    HStack(spacing: 12) {
                        Label(mod.manifest.author, systemImage: "person")
                        Label("v\(mod.manifest.version)", systemImage: "tag")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textLight)
                }

                Color.stardewDivider.opacity(0.4).frame(height: 1)

                // Status
                HStack {
                    Label(
                        mod.isEnabled ? "Enabled" : "Disabled",
                        systemImage: mod.isEnabled ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mod.isEnabled ? Color.stardewGreen : Color.stardewRed)

                    Spacer()

                    let typeColor: Color = mod.modType == .codeMod ? .stardewPurple : .stardewOrange
                    Text(mod.modType.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(typeColor.opacity(0.1))
                        .foregroundStyle(typeColor)
                        .clipShape(Capsule())
                }

                // Description
                if let desc = mod.manifest.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .tracking(0.5)
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textLight)
                    }
                }

                // Content Pack info
                if let cpf = mod.manifest.contentPackFor {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content Pack For")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .tracking(0.5)
                        Label(cpf.uniqueID, systemImage: "link")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textLight)
                    }
                }

                // Dependencies
                if !mod.resolvedDependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dependencies")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textMuted)
                            .tracking(0.5)

                        ForEach(mod.resolvedDependencies) { dep in
                            HStack(spacing: 8) {
                                Image(systemName: depIcon(dep.status))
                                    .font(.system(size: 12))
                                    .foregroundStyle(depColor(dep.status))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dep.modName ?? dep.entry.uniqueID)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textDark)
                                    if !dep.entry.isRequired {
                                        Text("Optional")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.textMuted)
                                    }
                                }
                            }
                        }
                    }
                }

                // Unique ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique ID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                        .tracking(0.5)
                    Text(mod.manifest.uniqueID)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.textLight)
                        .textSelection(.enabled)
                }

                // Folder
                VStack(alignment: .leading, spacing: 4) {
                    Text("Folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                        .tracking(0.5)
                    Text(mod.folderName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textLight)

                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path(percentEncoded: false))
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }

                // Nexus link
                if let nexusId = mod.nexusModID {
                    Button {
                        appState.openNexusModPage(modId: nexusId)
                    } label: {
                        Label("View on Nexus Mods", systemImage: "globe")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.link)
                }

                Spacer()
            }
            .padding(16)
        }
        .background(Color.parchment)
    }

    private func depIcon(_ status: DependencyStatus) -> String {
        switch status {
        case .satisfied: return "checkmark.circle.fill"
        case .missing: return "xmark.circle.fill"
        case .disabled: return "pause.circle.fill"
        }
    }

    private func depColor(_ status: DependencyStatus) -> Color {
        switch status {
        case .satisfied: return .stardewGreen
        case .missing: return .stardewRed
        case .disabled: return .stardewOrange
        }
    }
}
