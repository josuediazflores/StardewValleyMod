import SwiftUI
import UniformTypeIdentifiers

struct InstalledModsView: View {
    @Environment(AppState.self) private var appState
    @State private var hoveredModID: String?
    @State private var isDeleteMode = false
    @State private var selectedForDeletion: Set<String> = []
    @State private var showBatchDeleteConfirmation = false
    @State private var isDropTargeted = false
    @State private var importedCount = 0
    @State private var showImportResult = false
    @State private var showNexusURLSheet = false
    @State private var nexusURLInput = ""
    @State private var isDownloadingFromURL = false

    var body: some View {
        @Bindable var state = appState

        HSplitView {
            // Mod list
            VStack(spacing: 0) {
                // Filter bar
                HStack(spacing: 12) {
                    StardewSegmentedPicker(
                        selection: $state.filterMode,
                        label: { $0.shortLabel }
                    )
                    .fixedSize()

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                        TextField("Search mods...", text: $state.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textDark)
                            .frame(width: 130)
                        if !appState.searchText.isEmpty {
                            Button {
                                appState.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.parchmentAlt)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.frameBorder.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.parchmentHeader)

                // Header bar with delete mode toggle
                HStack {
                    if isDeleteMode {
                        let count = selectedForDeletion.count
                        Text("\(count) mod\(count == 1 ? "" : "s") selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(count > 0 ? Color.stardewRed : Color.textMuted)

                        Spacer()

                        Button("Cancel") {
                            isDeleteMode = false
                            selectedForDeletion.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 13))

                        Button {
                            showBatchDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 11))
                                Text("Delete Selected")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(count > 0 ? Color.stardewRed : Color.stardewRed.opacity(0.3))
                            )
                        }
                        .buttonStyle(.borderless)
                        .disabled(count == 0)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                openFilePicker()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 11))
                                    Text("Import")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.stardewGreen)
                            }
                            .buttonStyle(.borderless)
                            .help("Import mod ZIP files")

                            Button {
                                openFolderPicker()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 11))
                                    Text("Add Folder")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.accentGold)
                            }
                            .buttonStyle(.borderless)
                            .help("Import mod folders")

                            Button {
                                nexusURLInput = ""
                                showNexusURLSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                    Text("Nexus URL")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.stardewBlue)
                            }
                            .buttonStyle(.borderless)
                            .help("Install from Nexus Mods URL")
                        }

                        Spacer()

                        Button {
                            isDeleteMode = true
                            selectedForDeletion.removeAll()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.stardewRed.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                        .help("Enter delete mode")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.parchmentHeader)

                Color.frameBorder.frame(height: 3)

                if appState.filteredMods.isEmpty {
                    if appState.searchText.isEmpty {
                        VStack(spacing: 16) {
                            StardewIcon(type: .arrowBox, size: 48)

                            Text("No mods installed")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textDark)

                            Text("Drag & drop mod folders or ZIP files here, or use the buttons above")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textMuted)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Button { openFilePicker() } label: {
                                    Text("Choose Files...")
                                        .font(.stardew(size: 16))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.stardewGreen)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)

                                Button { openFolderPicker() } label: {
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
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.textMuted.opacity(0.3))
                            Text("No mods match your search")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            let mods = appState.filteredMods
                            ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                                VStack(spacing: 0) {
                                    modRow(mod)

                                    if index < mods.count - 1 {
                                        Color.stardewDivider.opacity(0.2).frame(height: 1)
                                            .padding(.leading, 31)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 400)
            .background(Color.parchment)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.stardewGreen, lineWidth: 3)
                    .opacity(isDropTargeted ? 1 : 0)
            )
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            .confirmationDialog(
                "Delete \(selectedForDeletion.count) Mod\(selectedForDeletion.count == 1 ? "" : "s")",
                isPresented: $showBatchDeleteConfirmation
            ) {
                Button("Delete \(selectedForDeletion.count) mod\(selectedForDeletion.count == 1 ? "" : "s")", role: .destructive) {
                    let modsToDelete = appState.mods.filter { selectedForDeletion.contains($0.id) }
                    for mod in modsToDelete {
                        appState.deleteMod(mod)
                    }
                    selectedForDeletion.removeAll()
                    isDeleteMode = false
                }
            } message: {
                let names = appState.mods
                    .filter { selectedForDeletion.contains($0.id) }
                    .map { $0.manifest.name }
                    .joined(separator: ", ")
                Text("Are you sure you want to delete these mods? This will remove them from disk and cannot be undone.\n\n\(names)")
            }

            .alert("Import Complete", isPresented: $showImportResult) {
                Button("OK") {}
            } message: {
                Text("Successfully imported \(importedCount) mod(s).")
            }
            .sheet(isPresented: $showNexusURLSheet) {
                VStack(spacing: 16) {
                    Text("Install from Nexus URL")
                        .font(.stardew(size: 22))
                        .foregroundStyle(Color.textDark)

                    Text("Paste a Nexus Mods link to download and install")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)

                    TextField("https://www.nexusmods.com/stardewvalley/mods/...", text: $nexusURLInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showNexusURLSheet = false
                        }
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                        .buttonStyle(.plain)

                        Button {
                            isDownloadingFromURL = true
                            showNexusURLSheet = false
                            appState.importFromNexusURL(nexusURLInput)
                            isDownloadingFromURL = false
                        } label: {
                            if isDownloadingFromURL {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Install")
                                    .font(.stardew(size: 16))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(nexusURLInput.isEmpty ? Color.stardewGreen.opacity(0.4) : Color.stardewGreen)
                        )
                        .buttonStyle(.plain)
                        .disabled(nexusURLInput.isEmpty)
                    }
                }
                .padding(24)
                .frame(width: 460)
                .background(Color.parchment)
            }
            .onChange(of: appState.showImportPicker) { _, newValue in
                if newValue {
                    appState.showImportPicker = false
                    openFilePicker()
                }
            }

            // Detail inspector
            if !isDeleteMode, let mod = appState.selectedMod {
                ModDetailView(mod: mod)
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            }
        }
    }

    @ViewBuilder
    private func modRow(_ mod: Mod) -> some View {
        HStack(spacing: 0) {
            // Checkbox in delete mode
            if isDeleteMode {
                if mod.isBuiltIn {
                    // Empty space to keep alignment
                    Color.clear.frame(width: 24, height: 24)
                        .padding(.trailing, 8)
                } else {
                    Button {
                        if selectedForDeletion.contains(mod.id) {
                            selectedForDeletion.remove(mod.id)
                        } else {
                            selectedForDeletion.insert(mod.id)
                        }
                    } label: {
                        Image(systemName: selectedForDeletion.contains(mod.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selectedForDeletion.contains(mod.id) ? Color.stardewRed : Color.textMuted.opacity(0.4))
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 8)
                }
            }

            // Left: mod info
            HStack(spacing: 10) {
                // Enable/disable dot
                Circle()
                    .fill(mod.isEnabled ? Color.stardewGreen : Color.stardewRed.opacity(0.5))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(mod.manifest.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textDark)
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

                        if mod.resolvedDependencies.contains(where: { $0.status != .satisfied && $0.entry.isRequired }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                                .help("Missing or disabled dependencies")
                        }
                    }

                    Text(mod.manifest.author)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textLight)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            // Right: version + type badge
            VStack(alignment: .trailing, spacing: 3) {
                Text("v\(mod.manifest.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textLight)

                let typeColor: Color = mod.modType == .codeMod ? .stardewPurple : .stardewOrange
                Text(mod.modType.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.1))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .opacity(isDeleteMode && mod.isBuiltIn ? 0.3 : mod.isEnabled ? 1.0 : 0.5)
        .background(
            isDeleteMode && selectedForDeletion.contains(mod.id)
                ? Color.stardewRed.opacity(0.08)
                : appState.selectedModID == mod.id && !isDeleteMode
                    ? Color.rowSelected
                    : hoveredModID == mod.id
                        ? Color.rowHover
                        : Color.clear
        )
        .overlay(alignment: .leading) {
            if !isDeleteMode && appState.selectedModID == mod.id {
                Color.accentGold.frame(width: 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isDeleteMode {
                if !mod.isBuiltIn {
                    if selectedForDeletion.contains(mod.id) {
                        selectedForDeletion.remove(mod.id)
                    } else {
                        selectedForDeletion.insert(mod.id)
                    }
                }
            } else {
                appState.selectedModID = mod.id
            }
        }
        .onHover { hovering in
            hoveredModID = hovering ? mod.id : nil
        }
        .contextMenu {
            if !isDeleteMode {
                if !mod.isBuiltIn {
                    Button(mod.isEnabled ? "Disable Mod" : "Enable Mod") {
                        toggleMod(mod)
                    }
                    Divider()
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
                }
                Button("Copy Unique ID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(mod.manifest.uniqueID, forType: .string)
                }
            }
        }
    }

    private func toggleMod(_ mod: Mod) {
        if mod.isEnabled {
            appState.performDisableMod(mod)
        } else {
            appState.performEnableMod(mod)
        }
    }

    // MARK: - Import

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
