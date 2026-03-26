import SwiftUI

struct ModDetailView: View {
    let mod: Mod
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(mod.manifest.name)
                        .font(.title2.weight(.bold))

                    HStack(spacing: 12) {
                        Label(mod.manifest.author, systemImage: "person")
                        Label("v\(mod.manifest.version)", systemImage: "tag")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Status
                HStack {
                    Label(
                        mod.isEnabled ? "Enabled" : "Disabled",
                        systemImage: mod.isEnabled ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(mod.isEnabled ? .green : .red)

                    Spacer()

                    Text(mod.modType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }

                // Description
                if let desc = mod.manifest.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.headline)
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Content Pack info
                if let cpf = mod.manifest.contentPackFor {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content Pack For")
                            .font(.headline)
                        Label(cpf.uniqueID, systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Dependencies
                if !mod.resolvedDependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dependencies")
                            .font(.headline)

                        ForEach(mod.resolvedDependencies) { dep in
                            HStack(spacing: 8) {
                                Image(systemName: depIcon(dep.status))
                                    .foregroundStyle(depColor(dep.status))

                                VStack(alignment: .leading) {
                                    Text(dep.modName ?? dep.entry.uniqueID)
                                        .font(.subheadline)
                                    if !dep.entry.isRequired {
                                        Text("Optional")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Unique ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique ID")
                        .font(.headline)
                    Text(mod.manifest.uniqueID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                // Folder
                VStack(alignment: .leading, spacing: 4) {
                    Text("Folder")
                        .font(.headline)
                    Text(mod.folderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path(percentEncoded: false))
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                // Nexus link
                if let nexusId = mod.nexusModID {
                    Button {
                        appState.openNexusModPage(modId: nexusId)
                    } label: {
                        Label("View on Nexus Mods", systemImage: "globe")
                    }
                    .buttonStyle(.link)
                }

                Spacer()
            }
            .padding()
        }
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
        case .satisfied: return .green
        case .missing: return .red
        case .disabled: return .yellow
        }
    }
}
