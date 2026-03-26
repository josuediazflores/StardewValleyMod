import SwiftUI

struct ModRowView: View {
    let mod: Mod
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: modTypeIcon)
                .font(.title3)
                .foregroundStyle(modTypeColor)
                .frame(width: 28)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
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

                HStack(spacing: 8) {
                    Text(mod.manifest.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("v\(mod.manifest.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(mod.modType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(modTypeColor.opacity(0.1))
                        .foregroundStyle(modTypeColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Dependency warning
            if mod.resolvedDependencies.contains(where: { $0.status != .satisfied && $0.entry.isRequired }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Missing or disabled dependencies")
            }

            // Toggle
            if !mod.isBuiltIn {
                Toggle("", isOn: .constant(mod.isEnabled))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onTapGesture { onToggle() }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Delete mod")
            }
        }
        .padding(.vertical, 4)
        .opacity(mod.isEnabled ? 1.0 : 0.6)
    }

    private var modTypeIcon: String {
        switch mod.modType {
        case .codeMod: return "gearshape.fill"
        case .contentPack: return "doc.fill"
        case .unknown: return "questionmark.square"
        }
    }

    private var modTypeColor: Color {
        switch mod.modType {
        case .codeMod: return .purple
        case .contentPack: return .orange
        case .unknown: return .gray
        }
    }
}
