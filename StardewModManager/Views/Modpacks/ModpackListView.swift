import SwiftUI

struct ModpackListView: View {
    @Environment(AppState.self) private var appState

    @State private var showCreateSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var modpackToDelete: Modpack?
    @State private var showCompareSheet = false
    @State private var showNearbyCompareSheet = false
    @State private var modpackSearchText = ""

    var body: some View {
        @Bindable var state = appState

        ScrollView {
            LazyVStack(spacing: 10) {
                // Play button + filter/search (when profile expanded)
                HStack(spacing: 12) {
                    Button {
                        appState.launchGame()
                    } label: {
                        HStack(spacing: 8) {
                            JunimoIcon(name: appState.selectedJunimoName, size: 24)
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                            Text(L.s("modpack_list_play"))
                                .font(.stardew(size: 24))
                                .foregroundStyle(Color.textDark)
                                .frame(height: 24)
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentGold)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.frameBorder, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(PlayButtonStyle())
                    .disabled(!appState.settings.isSMAPIInstalled)
                    .help(L.s("modpack_list_play_help"))

                    if appState.expandedModpackID != nil {
                        StardewSegmentedPicker(
                            selection: $state.filterMode,
                            label: { $0.shortLabel }
                        )
                        .fixedSize()
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                        TextField(L.s("modpack_search_profiles"), text: $modpackSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textDark)
                            .frame(width: 130)
                        if !modpackSearchText.isEmpty {
                            Button {
                                modpackSearchText = ""
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
                .padding(.bottom, 4)

                // Profiles header
                HStack(spacing: 8) {
                    Text(L.s("modpack_list_profiles"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                        .tracking(0.8)

                    VStack { Divider().overlay(Color.stardewDivider.opacity(0.5)) }

                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text(L.s("modpack_list_new"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(L.s("modpack_list_from_file")) { importFromFile() }
                        Button(L.s("modpack_list_from_clipboard")) { appState.importModpackFromClipboard() }
                        Divider()
                        Button(L.s("modpack_list_from_url")) { showImportSheet = true }
                        Button(L.s("modpack_list_from_nexus")) { showImportSheet = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                            Text(L.s("common_import"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentGold)
                        .foregroundStyle(Color.textDark)
                        .clipShape(Capsule())
                    }

                    if appState.modpacks.count >= 2 {
                        Button {
                            showCompareSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 10))
                                Text(L.s("modpack_list_compare"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.stardewBlue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showNearbyCompareSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 10))
                            Text(L.s("modpack_list_nearby"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.stardewPurple)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)

                // Vanilla profile (always present, not editable)
                HStack(spacing: 10) {
                    Image(systemName: "leaf")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.stardewGreen)

                    Text(L.s("modpack_list_vanilla"))
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)

                    Text(L.s("modpack_builtin"))
                        .font(.stardew(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.stardewGreen.opacity(0.15))
                        .foregroundStyle(Color.stardewGreen)
                        .clipShape(Capsule())

                    Text(L.s("modpack_list_zero_mods"))
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)

                    Spacer()

                    Button {
                        applyVanilla()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text(L.s("modpack_load_profile"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.stardewGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.parchmentAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.frameBorder, lineWidth: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.frameBorderDark, lineWidth: 1)
                        .padding(2)
                )

                // Saved modpacks
                if appState.modpacks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textMuted.opacity(0.3))
                        Text(L.s("modpack_list_no_profiles"))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(.vertical, 24)
                } else {
                    let displayedModpacks = modpackSearchText.isEmpty
                        ? appState.modpacks
                        : appState.modpacks.filter {
                            $0.name.localizedCaseInsensitiveContains(modpackSearchText)
                        }
                    ForEach(displayedModpacks) { modpack in
                        ExpandableModpackCardView(
                            modpack: modpack,
                            isActive: appState.activeModpackID == modpack.id,
                            isExpanded: appState.expandedModpackID == modpack.id,
                            onApply: { applyModpack(modpack) },
                            onExportJSON: { showExportPanel(modpack: modpack, asZIP: false) },
                            onExportZIP: { showExportPanel(modpack: modpack, asZIP: true) },
                            onShareSMM: { showShareSMMPanel(modpack: modpack) },
                            onCopyClipboard: { appState.copyModpackToClipboard(modpack) },
                            onDelete: {
                                modpackToDelete = modpack
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(Color.parchment)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text(L.s("modpack_list_status", appState.modpacks.count, appState.mods.count))
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Color.parchmentHeader
                    .overlay(alignment: .top) {
                        Color.stardewDivider.opacity(0.3).frame(height: 1)
                    }
            )
        }
        .sheet(isPresented: $showCreateSheet) {
            ModpackCreateSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showImportSheet) {
            ModpackImportSheet()
                .environment(appState)
        }
        .confirmationDialog(
            L.s("modpack_list_delete_confirm"),
            isPresented: $showDeleteConfirmation,
            presenting: modpackToDelete
        ) { modpack in
            Button(L.s("modpack_detail_delete_confirm", modpack.name), role: .destructive) {
                appState.deleteModpack(modpack)
            }
        } message: { modpack in
            Text(L.s("modpack_list_delete_message", modpack.name))
        }
        .onModDrop { urls in
            appState.importMods(from: urls)
        }
        .onChange(of: appState.expandedModpackID) { _, _ in
            appState.searchText = ""
            appState.filterMode = .all
        }
        .sheet(isPresented: $showCompareSheet) {
            CompareModpacksSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showNearbyCompareSheet) {
            NearbyCompareSheet()
                .environment(appState)
        }
    }

    // MARK: - Actions

    private func applyVanilla() {
        var count = 0
        var failedCount = 0
        for mod in appState.mods where mod.isEnabled && !mod.isBuiltIn {
            do {
                try ModManagementService.disableMod(mod, settings: appState.settings)
                count += 1
            } catch { failedCount += 1 }
        }
        DependencyResolver.resolveAll(mods: appState.mods)
        appState.activeModpackID = nil
        if failedCount > 0 {
            appState.showToast("Vanilla profile loaded but \(failedCount) mod\(failedCount == 1 ? "" : "s") failed to disable.", type: .warning)
        } else {
            appState.showToast("Vanilla profile loaded. \(count) mod\(count == 1 ? "" : "s") disabled.", type: .success)
        }
    }

    private func applyModpack(_ modpack: Modpack) {
        appState.applyModpack(modpack)
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = L.s("modpack_import_title")
        panel.allowedContentTypes = [.json, .zip, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.importModpackFromFile(url: url)
        }
    }

    private func showExportPanel(modpack: Modpack, asZIP: Bool) {
        let panel = NSSavePanel()
        panel.title = L.s("common_export")
        panel.nameFieldStringValue = "\(modpack.name).\(asZIP ? "zip" : "json")"

        if panel.runModal() == .OK, let url = panel.url {
            appState.exportModpack(modpack, asZIP: asZIP, to: url)
        }
    }

    private func showShareSMMPanel(modpack: Modpack) {
        let panel = NSSavePanel()
        panel.title = L.s("modpack_share")
        panel.nameFieldStringValue = "\(modpack.name).smm"

        if panel.runModal() == .OK, let url = panel.url {
            appState.shareModpackAsSMM(modpack, to: url)
        }
    }

}

// MARK: - Compare Modpacks Sheet

struct CompareModpacksSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var modpackA: Modpack?
    @State private var modpackB: Modpack?

    var body: some View {
        VStack(spacing: 16) {
            Text(L.s("compare_title"))
                .font(.stardew(size: 22))
                .foregroundStyle(Color.textDark)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.s("compare_profile_a"))
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)
                    Picker("", selection: $modpackA) {
                        Text(L.s("compare_select")).tag(nil as Modpack?)
                        ForEach(appState.modpacks) { mp in
                            Text(mp.name).tag(mp as Modpack?)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.s("compare_profile_b"))
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textMuted)
                    Picker("", selection: $modpackB) {
                        Text(L.s("compare_select")).tag(nil as Modpack?)
                        ForEach(appState.modpacks) { mp in
                            Text(mp.name).tag(mp as Modpack?)
                        }
                    }
                    .labelsHidden()
                }
            }

            if let a = modpackA, let b = modpackB {
                let enabledA = Set(a.entries.filter(\.isEnabled).map(\.uniqueID))
                let enabledB = Set(b.entries.filter(\.isEnabled).map(\.uniqueID))
                let inBoth = enabledA.intersection(enabledB)
                let onlyA = enabledA.subtracting(enabledB)
                let onlyB = enabledB.subtracting(enabledA)

                // Summary
                HStack(spacing: 20) {
                    Label(L.s("compare_shared", inBoth.count), systemImage: "checkmark.circle")
                        .foregroundStyle(Color.stardewGreen)
                    Label(L.s("compare_only_a", onlyA.count), systemImage: "a.circle")
                        .foregroundStyle(Color.stardewOrange)
                    Label(L.s("compare_only_b", onlyB.count), systemImage: "b.circle")
                        .foregroundStyle(Color.stardewBlue)
                }
                .font(.stardew(size: 14))

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !inBoth.isEmpty {
                            sectionHeader(L.s("compare_in_both"), color: .stardewGreen)
                            ForEach(sortedNames(ids: inBoth, from: a, b), id: \.self) { name in
                                modRow(name, color: .stardewGreen)
                            }
                        }
                        if !onlyA.isEmpty {
                            sectionHeader(L.s("compare_only_in", a.name), color: .stardewOrange)
                            ForEach(sortedNames(ids: onlyA, from: a, b), id: \.self) { name in
                                modRow(name, color: .stardewOrange)
                            }
                        }
                        if !onlyB.isEmpty {
                            sectionHeader(L.s("compare_only_in", b.name), color: .stardewBlue)
                            ForEach(sortedNames(ids: onlyB, from: a, b), id: \.self) { name in
                                modRow(name, color: .stardewBlue)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                Text(L.s("compare_select_hint"))
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
                    .frame(maxHeight: .infinity)
            }

            Button(L.s("common_done")) { dismiss() }
                .font(.stardew(size: 16))
                .buttonStyle(.plain)
                .foregroundStyle(Color.textMuted)
        }
        .padding(24)
        .frame(width: 520, height: 500)
        .background(Color.parchment)
    }

    private func sortedNames(ids: Set<String>, from a: Modpack, _ b: Modpack) -> [String] {
        let allEntries = a.entries + b.entries
        let nameMap = Dictionary(allEntries.map { ($0.uniqueID, $0.name) }, uniquingKeysWith: { first, _ in first })
        return ids.map { nameMap[$0] ?? $0 }.sorted()
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.stardew(size: 13))
            .foregroundStyle(color)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func modRow(_ name: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(Color.textDark)
        }
        .padding(.vertical, 2)
    }
}
