import SwiftUI
import UniformTypeIdentifiers

struct InstalledModsView: View {
    @Environment(AppState.self) private var appState
    @State private var hoveredModID: String?
    @State private var isBatchMode = false
    @State private var selectedModIDs: Set<String> = []
    @State private var showBatchDeleteConfirmation = false
    @State private var isDropTargeted = false
    @State private var showNexusURLSheet = false
    @State private var nexusURLInput = ""
    @State private var isDownloadingFromURL = false
    @FocusState private var isListFocused: Bool
    @State private var selectionAnchor: String?

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
                        TextField(L.s("installed_search"), text: $state.searchText)
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

                // Header bar with batch mode toggle
                HStack(spacing: 8) {
                    if isBatchMode {
                        let count = selectedModIDs.count
                        Text(L.s("installed_selected_count", count))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(count > 0 ? Color.textDark : Color.textMuted)

                        Button {
                            let selectableIDs = Set(appState.filteredMods.filter { !$0.isBuiltIn }.map(\.id))
                            if selectedModIDs == selectableIDs {
                                selectedModIDs.removeAll()
                            } else {
                                selectedModIDs = selectableIDs
                            }
                        } label: {
                            let allSelected = selectedModIDs == Set(appState.filteredMods.filter { !$0.isBuiltIn }.map(\.id))
                            Text(allSelected ? L.s("installed_deselect_all") : L.s("installed_select_all"))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Button {
                            appState.batchEnableMods(selectedModIDs)
                            selectedModIDs.removeAll()
                            isBatchMode = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text(L.s("installed_enable"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(count > 0 ? Color.stardewGreen : Color.stardewGreen.opacity(0.3))
                            )
                        }
                        .buttonStyle(.borderless)
                        .disabled(count == 0)

                        Button {
                            appState.batchDisableMods(selectedModIDs)
                            selectedModIDs.removeAll()
                            isBatchMode = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                Text(L.s("installed_disable"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(count > 0 ? Color.stardewOrange : Color.stardewOrange.opacity(0.3))
                            )
                        }
                        .buttonStyle(.borderless)
                        .disabled(count == 0)

                        Button {
                            showBatchDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 11))
                                Text(L.s("common_delete"))
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

                        Button(L.s("common_cancel")) {
                            isBatchMode = false
                            selectedModIDs.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 13))
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                openFilePicker()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 11))
                                    Text(L.s("installed_import"))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.stardewGreen)
                            }
                            .buttonStyle(.borderless)
                            .help(L.s("installed_import_help"))

                            Button {
                                openFolderPicker()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 11))
                                    Text(L.s("installed_add_folder"))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.textDark)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentGold)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(L.s("installed_add_folder_help"))

                            Button {
                                nexusURLInput = ""
                                showNexusURLSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                    Text(L.s("installed_nexus_url"))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.textDark)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentGold)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(L.s("installed_nexus_url_help"))
                        }

                        Spacer()

                        if !appState.modUpdates.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 11))
                                Text(L.s("installed_update_count", appState.modUpdates.count))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.stardewBlue)
                        } else if appState.isCheckingUpdates {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                                Text(L.s("installed_checking"))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Color.textMuted)
                        }

                        Button {
                            isBatchMode = true
                            selectedModIDs.removeAll()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 14))
                                Text(L.s("installed_select"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.textLight)
                        }
                        .buttonStyle(.borderless)
                        .help(L.s("installed_select_help"))
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

                            Text(L.s("installed_no_mods"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textDark)

                            Text(L.s("installed_no_mods_hint"))
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textMuted)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Button { openFilePicker() } label: {
                                    Text(L.s("installed_choose_files"))
                                        .font(.stardew(size: 16))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.stardewGreen)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)

                                Button { openFolderPicker() } label: {
                                    Text(L.s("installed_choose_folder"))
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
                            Text(L.s("installed_no_results"))
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                                let mods = appState.filteredMods
                                ForEach(Array(mods.enumerated()), id: \.element.id) { index, mod in
                                    VStack(spacing: 0) {
                                        modRow(mod)

                                        if index < mods.count - 1 {
                                            Color.stardewDivider.opacity(0.2).frame(height: 1)
                                                .padding(.leading, 31)
                                        }
                                    }
                                    .id(mod.id)
                                }
                            }
                        }
                        .focusable()
                        .focused($isListFocused)
                        .focusEffectDisabled()
                        .onKeyPress { keyPress in
                            handleKeyPress(keyPress, proxy: proxy)
                        }
                        .onAppear { isListFocused = true }
                    }
                }
            }
            .frame(minWidth: 500)
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
                L.s("installed_delete_title", selectedModIDs.count),
                isPresented: $showBatchDeleteConfirmation
            ) {
                Button(L.s("installed_delete_title", selectedModIDs.count), role: .destructive) {
                    let modsToDelete = appState.mods.filter { selectedModIDs.contains($0.id) }
                    appState.softDeleteMods(modsToDelete)
                    selectedModIDs.removeAll()
                    isBatchMode = false
                }
            } message: {
                let names = appState.mods
                    .filter { selectedModIDs.contains($0.id) }
                    .map { $0.manifest.name }
                    .joined(separator: ", ")
                Text(L.s("installed_delete_confirm") + "\n\n\(names)")
            }

            .sheet(isPresented: $showNexusURLSheet) {
                VStack(spacing: 16) {
                    Text(L.s("installed_nexus_sheet_title"))
                        .font(.stardew(size: 22))
                        .foregroundStyle(Color.textDark)

                    Text(L.s("installed_nexus_sheet_desc"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)

                    TextField(L.s("installed_nexus_placeholder"), text: $nexusURLInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    HStack(spacing: 12) {
                        Button(L.s("common_cancel")) {
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
                                Text(L.s("installed_nexus_install"))
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
            if !isBatchMode, let mod = appState.selectedMod {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            appState.selectedModID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ModDetailView(mod: mod)
                }
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
                .background(Color.parchment)
            }
        }
    }

    @ViewBuilder
    private func modRow(_ mod: Mod) -> some View {
        HStack(spacing: 0) {
            // Checkbox in delete mode
            if isBatchMode {
                if mod.isBuiltIn {
                    // Empty space to keep alignment
                    Color.clear.frame(width: 24, height: 24)
                        .padding(.trailing, 8)
                } else {
                    Button {
                        if selectedModIDs.contains(mod.id) {
                            selectedModIDs.remove(mod.id)
                        } else {
                            selectedModIDs.insert(mod.id)
                        }
                    } label: {
                        Image(systemName: selectedModIDs.contains(mod.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selectedModIDs.contains(mod.id) ? Color.accentGold : Color.textMuted.opacity(0.4))
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

                        if let folder = mod.subfolder {
                            Text(folder)
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentGold.opacity(0.15))
                                .foregroundStyle(Color.accentGoldDark)
                                .clipShape(Capsule())
                        }

                        if mod.isBuiltIn {
                            Text(L.s("row_built_in"))
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
                                .foregroundStyle(Color.stardewOrange)
                                .help(L.s("row_missing_deps"))
                        }
                    }

                    Text(mod.manifest.author)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textLight)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            // Right: version + update badge + type badge
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    Text("v\(mod.manifest.version)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textDark)

                    if let update = appState.modUpdates[mod.id] {
                        Button {
                            if let urlString = update.updateURL, let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text(update.newVersion)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.stardewBlue.opacity(0.15))
                            .foregroundStyle(Color.stardewBlue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(L.s("row_update_help"))
                    }
                }

                let typeColor: Color = mod.modType == .codeMod ? .stardewPurple : .stardewOrange
                Text(mod.modType.displayName)
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
        .opacity(isBatchMode && mod.isBuiltIn ? 0.3 : 1.0)
        .background(
            isBatchMode && selectedModIDs.contains(mod.id)
                ? Color.accentGold.opacity(0.2)
                : appState.selectedModID == mod.id && !isBatchMode
                    ? Color.rowSelected
                    : hoveredModID == mod.id
                        ? Color.rowHover
                        : Color.clear
        )
        .overlay(alignment: .leading) {
            if isBatchMode && selectedModIDs.contains(mod.id) {
                Color.accentGold.frame(width: 3)
            } else if !isBatchMode && appState.selectedModID == mod.id {
                Color.accentGold.frame(width: 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isBatchMode {
                if !mod.isBuiltIn {
                    if selectedModIDs.contains(mod.id) {
                        selectedModIDs.remove(mod.id)
                    } else {
                        selectedModIDs.insert(mod.id)
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
            if !isBatchMode {
                if !mod.isBuiltIn {
                    Button(mod.isEnabled ? L.s("installed_disable") : L.s("installed_enable")) {
                        toggleMod(mod)
                    }
                    Divider()
                }
                Button(L.s("detail_show_in_finder")) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: mod.folderURL.path)
                }
                Button(L.s("detail_unique_id")) {
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
            }
        }

        return true
    }

    // MARK: - Keyboard Navigation

    private func handleKeyPress(_ keyPress: KeyPress, proxy: ScrollViewProxy) -> KeyPress.Result {
        let shift = keyPress.modifiers.contains(.shift)
        let cmd = keyPress.modifiers.contains(.command)

        switch keyPress.key {
        case .upArrow:
            if shift { extendSelectionUp(proxy: proxy) } else { selectPreviousMod(proxy: proxy) }
            return .handled
        case .downArrow:
            if shift { extendSelectionDown(proxy: proxy) } else { selectNextMod(proxy: proxy) }
            return .handled
        case .space, .return:
            toggleSelectedMods()
            return .handled
        case .delete:
            deleteSelectedMods()
            return .handled
        case .escape:
            if isBatchMode {
                isBatchMode = false
                selectedModIDs.removeAll()
                selectionAnchor = nil
            } else {
                appState.selectedModID = nil
            }
            return .handled
        default:
            if cmd && keyPress.characters == "a" {
                isBatchMode = true
                selectedModIDs = Set(appState.filteredMods.filter { !$0.isBuiltIn }.map(\.id))
                return .handled
            }
            return .ignored
        }
    }

    private func selectNextMod(proxy: ScrollViewProxy) {
        let mods = appState.filteredMods
        guard !mods.isEmpty else { return }
        if let currentID = appState.selectedModID,
           let index = mods.firstIndex(where: { $0.id == currentID }),
           index + 1 < mods.count {
            appState.selectedModID = mods[index + 1].id
        } else {
            appState.selectedModID = mods[0].id
        }
        if let id = appState.selectedModID {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func selectPreviousMod(proxy: ScrollViewProxy) {
        let mods = appState.filteredMods
        guard !mods.isEmpty else { return }
        if let currentID = appState.selectedModID,
           let index = mods.firstIndex(where: { $0.id == currentID }),
           index > 0 {
            appState.selectedModID = mods[index - 1].id
        } else {
            appState.selectedModID = mods.last?.id
        }
        if let id = appState.selectedModID {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func extendSelectionDown(proxy: ScrollViewProxy) {
        let mods = appState.filteredMods
        guard !mods.isEmpty else { return }

        let currentID = appState.selectedModID ?? mods.first?.id
        guard let currentID, let index = mods.firstIndex(where: { $0.id == currentID }) else { return }

        if !isBatchMode {
            isBatchMode = true
            selectedModIDs = [currentID]
            selectionAnchor = currentID
        }

        if index + 1 < mods.count {
            let nextMod = mods[index + 1]
            appState.selectedModID = nextMod.id
            if !nextMod.isBuiltIn {
                selectedModIDs.insert(nextMod.id)
            }
            withAnimation { proxy.scrollTo(nextMod.id, anchor: .center) }
        }
    }

    private func extendSelectionUp(proxy: ScrollViewProxy) {
        let mods = appState.filteredMods
        guard !mods.isEmpty else { return }

        let currentID = appState.selectedModID ?? mods.last?.id
        guard let currentID, let index = mods.firstIndex(where: { $0.id == currentID }) else { return }

        if !isBatchMode {
            isBatchMode = true
            selectedModIDs = [currentID]
            selectionAnchor = currentID
        }

        if index > 0 {
            let prevMod = mods[index - 1]
            appState.selectedModID = prevMod.id
            if !prevMod.isBuiltIn {
                selectedModIDs.insert(prevMod.id)
            }
            withAnimation { proxy.scrollTo(prevMod.id, anchor: .center) }
        }
    }

    private func toggleSelectedMods() {
        if isBatchMode && !selectedModIDs.isEmpty {
            let modsToToggle = appState.mods.filter { selectedModIDs.contains($0.id) && !$0.isBuiltIn }
            let hasEnabled = modsToToggle.contains { $0.isEnabled }
            if hasEnabled {
                appState.batchDisableMods(selectedModIDs)
            } else {
                appState.batchEnableMods(selectedModIDs)
            }
        } else if let mod = appState.selectedMod, !mod.isBuiltIn {
            toggleMod(mod)
        }
    }

    private func deleteSelectedMods() {
        if isBatchMode && !selectedModIDs.isEmpty {
            showBatchDeleteConfirmation = true
        } else if let mod = appState.selectedMod, !mod.isBuiltIn {
            appState.softDeleteMods([mod])
        }
    }
}
