import SwiftUI

struct ModpackCreateSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""

    private var enabledCount: Int {
        appState.mods.filter { $0.isEnabled }.count
    }

    private var disabledCount: Int {
        appState.mods.filter { !$0.isEnabled }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L.s("modpack_create_title"))
                .font(.stardew(size: 24))
                .foregroundStyle(Color.textDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.parchmentHeader)

            Divider()
                .overlay(Color.stardewDivider)

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.s("modpack_create_name"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                    TextField(L.s("modpack_create_name_placeholder"), text: $name)
                        .font(.system(size: 14))
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L.s("modpack_create_description"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textDark)
                    TextField(L.s("modpack_create_desc_placeholder"), text: $description)
                        .font(.system(size: 14))
                        .textFieldStyle(.roundedBorder)
                }

                // Preview
                Text(L.s("modpack_create_preview", enabledCount, disabledCount))
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textLight)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.parchmentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(20)

            Spacer()

            // Buttons
            Divider()
                .overlay(Color.stardewDivider)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text(L.s("common_cancel"))
                        .font(.stardew(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.toggleOff.opacity(0.3))
                        .foregroundStyle(Color.textDark)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    appState.createModpackFromCurrentState(
                        name: name.trimmingCharacters(in: .whitespaces),
                        description: description.trimmingCharacters(in: .whitespaces)
                    )
                    dismiss()
                } label: {
                    Text(L.s("modpack_create_button"))
                        .font(.stardew(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.stardewGreen.opacity(0.4) : Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420, height: 340)
        .background(Color.parchment)
    }
}
