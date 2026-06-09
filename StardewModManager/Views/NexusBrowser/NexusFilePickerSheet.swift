import SwiftUI

/// Shown when a Nexus mod has no unambiguous main file (e.g. only optional files),
/// letting the user pick which file to install instead of guessing.
struct NexusFilePickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.s("file_picker_title"))
                        .font(.stardew(size: 22))
                        .foregroundStyle(Color.textDark)
                    Text(L.s("file_picker_subtitle"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.parchmentHeader)

            Color.frameBorder.frame(height: 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.nexusFilePickerFiles) { file in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textDark)
                                if let desc = file.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textLight)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 8) {
                                    if let version = file.version {
                                        Text("v\(version)")
                                    }
                                    if let size = file.sizeKb {
                                        Text(formatSize(size))
                                    }
                                    if let dateStr = L.formatTimestamp(file.uploadedTimestamp) {
                                        Text(dateStr)
                                    }
                                    if let category = file.categoryName {
                                        Text(category)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentGold.opacity(0.15))
                                            .foregroundStyle(Color.accentGoldDark)
                                            .clipShape(Capsule())
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                            }

                            Spacer()

                            Button {
                                guard let modId = appState.nexusFilePickerModId else { return }
                                appState.showNexusFilePicker = false
                                Task {
                                    await appState.downloadNexusFile(modId: modId, fileId: file.fileId)
                                }
                            } label: {
                                Label(L.s("nexus_detail_install"), systemImage: "arrow.down.circle")
                                    .font(.stardew(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.stardewGreen)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.parchmentAlt)
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .background(Color.parchment)
    }

    private func formatSize(_ kb: Int) -> String {
        if kb >= 1_048_576 { return String(format: "%.1f GB", Double(kb) / 1_048_576) }
        if kb >= 1024 { return String(format: "%.1f MB", Double(kb) / 1024) }
        return "\(kb) KB"
    }
}
