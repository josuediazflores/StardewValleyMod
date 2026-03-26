import SwiftUI

struct NexusModDetailView: View {
    let mod: NexusModInfo
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var files: [NexusModFileInfo] = []
    @State private var isLoadingFiles = false
    @State private var error: String?
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mod.name)
                    .font(.title2.weight(.bold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Mod info
                    HStack(spacing: 16) {
                        if let urlString = mod.pictureUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(.fill.tertiary)
                            }
                            .frame(width: 120, height: 90)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Label(mod.author, systemImage: "person")
                            Label("v\(mod.version)", systemImage: "tag")
                            if let downloads = mod.modDownloads {
                                Label("\(downloads) downloads", systemImage: "arrow.down.circle")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Text(mod.summary)
                        .font(.body)

                    Divider()

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            appState.openNexusModPage(modId: mod.modId)
                        } label: {
                            Label("View on Nexus", systemImage: "globe")
                        }
                        .buttonStyle(.bordered)

                        if !appState.settings.isNexusPremium {
                            Text("Direct download requires Nexus Premium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Files
                    Text("Files")
                        .font(.headline)

                    if isLoadingFiles {
                        ProgressView("Loading files...")
                    } else if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    } else if files.isEmpty {
                        Text("No files available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(files) { file in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.subheadline.weight(.medium))
                                    HStack(spacing: 8) {
                                        if let version = file.version {
                                            Text("v\(version)")
                                        }
                                        if let size = file.sizeKb {
                                            Text(formatSize(size))
                                        }
                                        if let category = file.categoryName {
                                            Text(category)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(.fill.tertiary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if appState.settings.isNexusPremium {
                                    Button {
                                        isDownloading = true
                                        Task {
                                            await appState.downloadAndInstallMod(modId: mod.modId, fileId: file.fileId)
                                            isDownloading = false
                                        }
                                    } label: {
                                        if isDownloading {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Label("Install", systemImage: "arrow.down.circle")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isDownloading)
                                } else {
                                    Button {
                                        appState.openNexusModPage(modId: mod.modId)
                                    } label: {
                                        Label("Download", systemImage: "globe")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 550, minHeight: 500)
        .task {
            isLoadingFiles = true
            do {
                if let key = appState.settings.nexusAPIKey {
                    await appState.nexusAPI.setAPIKey(key)
                }
                files = try await appState.nexusAPI.modFiles(modId: mod.modId)
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
