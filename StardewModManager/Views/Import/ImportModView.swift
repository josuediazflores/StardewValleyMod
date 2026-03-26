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
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 56))
                    .foregroundStyle(isTargeted ? .blue : .secondary)

                Text("Drag & Drop Mods Here")
                    .font(.title2.weight(.bold))

                Text("Drop mod folders or .zip files to install them")
                    .foregroundStyle(.secondary)

                Text("— or —")
                    .foregroundStyle(.tertiary)

                Button("Choose Files...") {
                    openFilePicker()
                }
                .buttonStyle(.borderedProminent)

                Button("Choose Folder...") {
                    openFolderPicker()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTargeted ? Color.blue : Color.secondary.opacity(0.3),
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
                    .font(.headline)

                HStack(spacing: 24) {
                    Label("Mod Folders", systemImage: "folder")
                    Label("ZIP Archives", systemImage: "doc.zipper")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("Each mod must contain a manifest.json file. ZIP files with multiple mods will be imported individually.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
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
