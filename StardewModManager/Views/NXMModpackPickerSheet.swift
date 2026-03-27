import SwiftUI

struct NXMModpackPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let importedMods: [Mod]

    var body: some View {
        VStack(spacing: 16) {
            Text("Mod Installed!")
                .font(.stardew(size: 24))
                .foregroundStyle(Color.textDark)

            Text("Add \(importedMods.map(\.manifest.name).joined(separator: ", ")) to a modpack?")
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMedium)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.modpacks.filter { $0.source != .currentProfile }) { modpack in
                        Button {
                            appState.addModsToModpack(modpack.id, mods: importedMods)
                            dismiss()
                        } label: {
                            HStack {
                                Text(modpack.name)
                                    .font(.stardew(size: 16))
                                    .foregroundStyle(Color.textDark)
                                Spacer()
                                Text("\(modpack.entries.count) mods")
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.parchmentAlt)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 250)

            Divider()

            Button("Don't add to any modpack") {
                dismiss()
            }
            .font(.stardew(size: 16))
            .foregroundStyle(Color.textLight)
        }
        .padding(20)
        .frame(width: 400)
        .background(Color.parchment)
    }
}
