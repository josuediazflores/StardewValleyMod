import SwiftUI

struct NXMModpackPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let importedMods: [Mod]

    @State private var showNewModpackField = false
    @State private var newModpackName = ""

    private var modNames: String {
        let names = appState.pendingNXMModNames
        if names.isEmpty {
            return importedMods.map(\.manifest.name).joined(separator: ", ")
        }
        return names.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.stardewGreen)

            Text("Mod Downloaded")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.textDark)

            Text("Where would you like to install **\(modNames)**?")
                .font(.system(size: 13))
                .foregroundStyle(Color.textMedium)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Color.stardewDivider.opacity(0.3).frame(height: 1)

            // Options
            ScrollView {
                VStack(spacing: 6) {
                    // Current Profile option
                    Button {
                        appState.installPendingNXMToCurrentProfile()
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.stardewGreen)
                                .frame(width: 8, height: 8)
                            Text("Current Profile")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textDark)
                            Spacer()
                            Text("Install now")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.stardewGreen.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.stardewGreen.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Existing modpacks
                    ForEach(appState.modpacks.filter { $0.source != .currentProfile }) { modpack in
                        Button {
                            appState.installPendingNXMToModpack(modpack.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.stardewPurple)
                                    .frame(width: 8, height: 8)
                                Text(modpack.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textDark)
                                Spacer()
                                Text("\(modpack.entries.count) mods")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.parchmentAlt)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // New Modpack option
                    if showNewModpackField {
                        HStack(spacing: 8) {
                            TextField("Modpack name", text: $newModpackName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                                .onSubmit {
                                    createAndInstall()
                                }

                            Button {
                                createAndInstall()
                            } label: {
                                Text("Create")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.stardewGreen)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(newModpackName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.parchmentAlt)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentGoldBorder.opacity(0.3), lineWidth: 1)
                                )
                        )
                    } else {
                        Button {
                            showNewModpackField = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.accentGold)
                                Text("New Modpack")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textDark)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentGoldBorder.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 250)

            Color.stardewDivider.opacity(0.3).frame(height: 1)

            Button {
                appState.cancelPendingNXM()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 420)
        .background(Color.parchment)
    }

    private func createAndInstall() {
        let name = newModpackName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        appState.installPendingNXMToNewModpack(name: name)
        dismiss()
    }
}
