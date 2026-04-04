import SwiftUI

struct NexusModDetailView: View {
    let mod: NexusModInfo
    var installedVersion: String?
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var files: [NexusModFileInfo] = []
    @State private var isLoadingFiles = false
    @State private var error: String?
    @State private var downloadingFileId: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mod.displayName)
                    .font(.stardew(size: 22))
                    .foregroundStyle(Color.textDark)
                    .lineLimit(1)
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
                VStack(alignment: .leading, spacing: 16) {
                    // Mod info
                    HStack(spacing: 16) {
                        if let urlString = mod.pictureUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.parchmentHeader)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(Color.textMuted)
                                    }
                            }
                            .frame(width: 120, height: 90)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label(mod.author ?? "Unknown", systemImage: "person")
                                .foregroundStyle(Color.textMedium)
                            Label("v\(mod.version ?? "?")", systemImage: "tag")
                                .foregroundStyle(Color.textMedium)
                            if let downloads = mod.modDownloads {
                                Label("\(downloads) downloads", systemImage: "arrow.down.circle")
                                    .foregroundStyle(Color.textMedium)
                            }
                            if let dateStr = L.formatISO(mod.updatedAt) ?? L.formatISO(mod.createdAt) {
                                Label(dateStr, systemImage: "clock")
                                    .foregroundStyle(Color.textMedium)
                            }
                            if let installed = installedVersion {
                                Label("v\(installed) installed", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Color.stardewGreen)
                            }
                        }
                        .font(.system(size: 13))
                    }

                    Text(mod.summary ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textLight)

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            appState.openNexusModPage(modId: mod.modId)
                        } label: {
                            Label(L.s("nexus_detail_view"), systemImage: "globe")
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.textDark)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentGold)
                                )
                        }
                        .buttonStyle(.plain)

                        if !appState.settings.isNexusPremium {
                            Text(L.s("nexus_detail_web_downloads"))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                        }
                    }

                    Color.stardewDivider.opacity(0.3).frame(height: 1)

                    // Files
                    Text(L.s("nexus_detail_files"))
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)

                    if isLoadingFiles {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L.s("nexus_detail_loading"))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textMuted)
                        }
                    } else if let error {
                        Text(error)
                            .foregroundStyle(Color.stardewRed)
                            .font(.system(size: 12))
                    } else if files.isEmpty {
                        Text(L.s("nexus_detail_no_files"))
                            .foregroundStyle(Color.textMuted)
                            .font(.system(size: 12))
                    } else {
                        ForEach(files) { file in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(file.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.textDark)
                                        if let installed = installedVersion, file.version == installed {
                                            Text(L.s("nexus_installed"))
                                                .font(.system(size: 9, weight: .semibold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.stardewGreen.opacity(0.15))
                                                .foregroundStyle(Color.stardewGreen)
                                                .clipShape(Capsule())
                                        }
                                    }
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

                                if appState.settings.isNexusPremium {
                                    Button {
                                        downloadingFileId = file.fileId
                                        Task {
                                            await appState.downloadAndInstallMod(modId: mod.modId, fileId: file.fileId)
                                            downloadingFileId = nil
                                        }
                                    } label: {
                                        if downloadingFileId == file.fileId {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(width: 80)
                                        } else {
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
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(downloadingFileId != nil)
                                } else {
                                    Button {
                                        appState.openWebDownloadSheet(modId: mod.modId, modName: mod.displayName)
                                        dismiss()
                                    } label: {
                                        Label(L.s("nexus_detail_download"), systemImage: "arrow.down.circle")
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
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.parchmentAlt)
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 550, minHeight: 500)
        .background(Color.parchment)
        .task {
            isLoadingFiles = true
            do {
                if let key = appState.settings.nexusAPIKey {
                    await appState.nexusAPI.setAPIKey(key)
                }
                files = try await appState.nexusAPI.modFiles(modId: mod.modId)
                files.sort { a, b in
                    let aIsMain = a.categoryName != "OLD_VERSION"
                    let bIsMain = b.categoryName != "OLD_VERSION"
                    if aIsMain != bIsMain { return aIsMain }
                    return (a.fileId) > (b.fileId)
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoadingFiles = false
        }
    }

    private func formatSize(_ kb: Int) -> String {
        if kb >= 1_048_576 { return String(format: "%.1f GB", Double(kb) / 1_048_576) }
        if kb >= 1024 { return String(format: "%.1f MB", Double(kb) / 1024) }
        return "\(kb) KB"
    }
}
