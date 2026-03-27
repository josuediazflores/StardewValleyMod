import SwiftUI
import UniformTypeIdentifiers

struct ImportModView: View {
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var importedCount = 0
    @State private var showImportResult = false

    var body: some View {
        VStack(spacing: 24) {
            // Drop zone
            VStack(spacing: 16) {
                StardewIcon(type: .arrowBox, size: 56)

                Text("Drag & Drop Mods Here")
                    .font(.stardew(size: 24))
                    .foregroundStyle(Color.textDark)

                Text("Drop mod folders or .zip files to install them")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textLight)

                Text("— or —")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)

                Button {
                    openFilePicker()
                } label: {
                    Text("Choose Files...")
                        .font(.stardew(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    openFolderPicker()
                } label: {
                    Text("Choose Folder...")
                        .font(.stardew(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentGold)
                        .foregroundStyle(Color.textDark)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isTargeted ? Color.stardewGreen : Color.accentGold.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
            )
            .padding(32)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported Formats:")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.textDark)

                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        StardewIcon(type: .chest, size: 14)
                        Text("Mod Folders")
                            .font(.stardew(size: 14))
                    }
                    HStack(spacing: 6) {
                        StardewIcon(type: .scroll, size: 14)
                        Text("ZIP Archives")
                            .font(.stardew(size: 14))
                    }
                }
                .foregroundStyle(Color.textLight)

                Text("Each mod must contain a manifest.json file. ZIP files with multiple mods will be imported individually.")
                    .font(.stardew(size: 13))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .background(Color.parchment)
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text("Successfully imported \(importedCount) mod(s).")
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.title = "Select Mod ZIP Files"

        if panel.runModal() == .OK {
            appState.importMods(from: panel.urls)
            importedCount = panel.urls.count
            showImportResult = true
        }
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.title = "Select Mod Folders"

        if panel.runModal() == .OK {
            appState.importMods(from: panel.urls)
            importedCount = panel.urls.count
            showImportResult = true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                appState.importMods(from: urls)
                importedCount = urls.count
                showImportResult = true
            }
        }

        return true
    }
}
