import Foundation
import SwiftUI

extension AppState {

    // MARK: - Modpack Selectors

    var activeModpack: Modpack? {
        guard let id = activeModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    var selectedModpack: Modpack? {
        guard let id = selectedModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    func filteredEntriesForModpack(_ modpack: Modpack) -> [ModpackEntry] {
        // Start with explicit modpack entries
        var existingIDs = Set(modpack.entries.map(\.uniqueID))
        var result = modpack.entries

        // Merge in all installed mods not already in the modpack (as disabled);
        // duplicate on-disk copies of one mod merge to a single entry
        for mod in mods {
            if !existingIDs.contains(mod.id) {
                existingIDs.insert(mod.id)
                result.append(ModpackEntry(mod: mod, isEnabled: false))
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        switch filterMode {
        case .all: break
        case .enabled: result = result.filter { $0.isEnabled }
        case .disabled: result = result.filter { !$0.isEnabled }
        case .codeMods:
            let codeModIDs = Set(mods.filter { $0.modType == .codeMod }.map(\.id))
            result = result.filter { codeModIDs.contains($0.uniqueID) }
        case .contentPacks:
            let cpIDs = Set(mods.filter { $0.modType == .contentPack }.map(\.id))
            result = result.filter { cpIDs.contains($0.uniqueID) }
        case .updates:
            result = result.filter { modUpdates[$0.uniqueID] != nil }
        }

        return result
    }

    // MARK: - Persistence & Loading

    func loadModpacks() {
        modpacks = ModpackService.loadModpacks(settings: settings)
    }

    /// Persists modpacks, surfacing a failure via errorMessage instead of silently
    /// dropping it. Used by the entry-mutation/sync sites that previously swallowed
    /// the save error with `try?`.
    func persistModpacks() {
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Modpack CRUD

    /// Creates a default modpack from pre-existing mods on first launch
    func createInitialModpackIfNeeded() {
        guard modpacks.isEmpty else { return }
        let userMods = mods.filter { !$0.isBuiltIn }
        guard !userMods.isEmpty else { return }

        let modpack = ModpackService.createModpack(
            name: "My Mods",
            description: "Auto-created from your existing mods",
            from: userMods
        )
        modpacks.append(modpack)
        activeModpackID = modpack.id
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createModpackFromCurrentState(name: String, description: String) {
        let modpack = ModpackService.createModpack(name: name, description: description, from: mods)
        modpacks.append(modpack)
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyModpack(_ modpack: Modpack) {
        Task { await applyModpackAsync(modpack) }
    }

    /// Awaitable apply. Returns true when the profile applied without a fatal error
    /// (non-fatal per-mod failures/missing are still reported via toast). Callers that
    /// need to react to the outcome (e.g. the detail sheet's result alert) await this.
    @discardableResult
    func applyModpackAsync(_ modpack: Modpack) async -> Bool {
        guard !isModpackLoading else { return false }
        isModpackLoading = true
        modpackError = nil
        defer { isModpackLoading = false }
        do {
                // The mass folder moves run off the main thread so a large profile
                // switch can't beachball the UI. loadMods() then rebuilds `mods` from
                // disk on the MainActor, discarding the detached in-memory mutations.
                let currentSettings = settings
                let snapshot = mods
                let result = try await Task.detached(priority: .userInitiated) {
                    try ModpackService.applyModpack(modpack, mods: snapshot, settings: currentSettings)
                }.value
                activeModpackID = modpack.id

                // Always refresh mods from disk, even if some moves failed
                loadMods()

                let enabledCount = mods.filter { !$0.isBuiltIn && $0.isEnabled }.count
                if !result.failures.isEmpty {
                    let names = result.failures.prefix(3).map(\.name).joined(separator: ", ")
                    let suffix = result.failures.count > 3 ? ", …" : ""
                    showToast("Profile loaded, but \(result.failures.count) mod\(result.failures.count == 1 ? "" : "s") could not be moved: \(names)\(suffix)", type: .warning)
                } else if !result.missing.isEmpty {
                    let names = result.missing.map(\.name).joined(separator: ", ")
                    showToast("Profile loaded (\(enabledCount) mods enabled). Missing: \(names)", type: .warning)
                } else {
                    showToast("Profile \"\(modpack.name)\" loaded — \(enabledCount) mods enabled", type: .success)
                }
                SoundService.play(.bigSelect)
                return true
            } catch {
                modpackError = error.localizedDescription
                loadMods()
                return false
            }
    }

    func deleteModpack(_ modpack: Modpack) {
        do {
            try ModpackService.deleteModpack(modpack, settings: settings)
            modpacks.removeAll { $0.id == modpack.id }
            if activeModpackID == modpack.id { activeModpackID = nil }
            if selectedModpackID == modpack.id { selectedModpackID = nil }
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameModpack(_ modpack: Modpack, to newName: String) {
        guard let index = modpacks.firstIndex(where: { $0.id == modpack.id }) else { return }
        modpacks[index].name = newName
        modpacks[index].updatedAt = Date()
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Export & Share

    func exportModpack(_ modpack: Modpack, asZIP: Bool, to url: URL) {
        do {
            if asZIP {
                try ModpackService.exportAsZIP(modpack, mods: mods, settings: settings, to: url)
            } else {
                try ModpackService.exportAsJSON(modpack, to: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shareModpackAsSMM(_ modpack: Modpack, to url: URL) {
        do {
            let shareable = ShareableModpack.from(modpack)
            let data = try shareable.toJSON()
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyModpackToClipboard(_ modpack: Modpack) {
        do {
            let shareable = ShareableModpack.from(modpack)
            let data = try shareable.toJSON()
            guard let json = String(data: data, encoding: .utf8) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Import

    func importModpackFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              let data = string.data(using: .utf8) else {
            errorMessage = "No valid modpack data found in clipboard."
            return
        }
        do {
            // Decode inside the do/catch so a version-mismatch (or any decode) error
            // is surfaced instead of being swallowed into a generic message.
            let shareable = try ShareableModpack.fromJSON(data)
            let modpack = shareable.toModpack()
            modpacks.append(modpack)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importSMMFile(url: URL) {
        do {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let shareable = try ShareableModpack.fromJSON(data)
            let modpack = shareable.toModpack()
            modpacks.append(modpack)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importModpackFromFile(url: URL) {
        Task {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

            do {
                if url.pathExtension.lowercased() == "smm" {
                    let data = try Data(contentsOf: url)
                    let shareable = try ShareableModpack.fromJSON(data)
                    modpacks.append(shareable.toModpack())
                } else if url.pathExtension.lowercased() == "json" {
                    let modpack = try ModpackService.importFromJSON(at: url)
                    modpacks.append(modpack)
                } else {
                    // Extraction + recursive mod copies run off the main thread.
                    let currentSettings = settings
                    let existing = mods
                    let (modpack, imported) = try await Task.detached(priority: .userInitiated) {
                        try ModpackService.importFromZIP(at: url, settings: currentSettings, existingMods: existing)
                    }.value
                    modpacks.append(modpack)
                    for newMod in imported {
                        mods.removeAll { $0.id == newMod.id }
                        mods.append(newMod)
                    }
                    mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
                    DependencyResolver.resolveAll(mods: mods)
                }
                try ModpackService.saveModpacks(modpacks, settings: settings)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func importModpackFromURL(urlString: String) async {
        isModpackLoading = true
        modpackError = nil
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = try await externalDownloader.downloadFile(from: urlString, to: tempDir)
            let currentSettings = settings
            let existing = mods
            let (modpack, imported) = try await Task.detached(priority: .userInitiated) {
                try ModpackService.importFromZIP(at: localURL, settings: currentSettings, existingMods: existing)
            }.value
            try? FileManager.default.removeItem(at: localURL)

            modpacks.append(modpack)
            for newMod in imported {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            modpackError = error.localizedDescription
        }
        isModpackLoading = false
    }

    func importNexusCollection(slug: String) async {
        isModpackLoading = true
        modpackError = nil
        do {
            let info = try await nexusAPI.collectionDetails(slug: slug)
            let collectionMods = try await nexusAPI.collectionMods(slug: slug)

            let entries = collectionMods.map { cm in
                ModpackEntry(
                    // Nexus gives no SMAPI id; use a stable non-empty synthetic id so
                    // entries don't all collide on "" and applyModpack can still resolve
                    // them to installed mods via nexusModID.
                    uniqueID: "nexus:\(cm.modId)",
                    name: cm.name,
                    version: cm.version,
                    nexusModID: cm.modId,
                    nexusFileID: cm.fileId,
                    isEnabled: !(cm.optional ?? false)
                )
            }

            let modpack = Modpack(
                id: UUID(),
                name: info.name,
                description: info.summary ?? "",
                entries: entries,
                source: .nexusCollection(collectionId: info.id),
                includesFiles: false,
                bundleFolderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            modpacks.append(modpack)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            modpackError = error.localizedDescription
        }
        isModpackLoading = false
    }

    // MARK: - Entry Mutations

    func toggleModpackEntry(modpackID: UUID, entryID: String) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }

        if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == entryID }) {
            modpacks[idx].entries[entryIdx].isEnabled.toggle()
        } else if let mod = mods.first(where: { $0.id == entryID }) {
            // Entry was auto-merged from installed mods — persist it as enabled
            modpacks[idx].entries.append(ModpackEntry(mod: mod, isEnabled: true))
        }

        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func removeModpackEntry(modpackID: UUID, entryID: String) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        modpacks[idx].entries.removeAll { $0.uniqueID == entryID }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func batchToggleModpackEntries(modpackID: UUID, entryIDs: Set<String>, enabled: Bool) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        for entryID in entryIDs {
            if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == entryID }) {
                modpacks[idx].entries[entryIdx].isEnabled = enabled
            }
        }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func removeModFromAllModpacks(_ modID: String) {
        var changed = false
        for i in modpacks.indices {
            let before = modpacks[i].entries.count
            modpacks[i].entries.removeAll { $0.uniqueID == modID }
            if modpacks[i].entries.count != before {
                modpacks[i].updatedAt = Date()
                changed = true
            }
        }
        if changed {
            persistModpacks()
        }
    }

    func batchRemoveModpackEntries(modpackID: UUID, entryIDs: Set<String>) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        modpacks[idx].entries.removeAll { entryIDs.contains($0.uniqueID) }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func addModToModpack(modpackID: UUID, mod: Mod) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        guard !modpacks[idx].entries.contains(where: { $0.uniqueID == mod.id }) else { return }
        let entry = ModpackEntry(mod: mod, isEnabled: true)
        modpacks[idx].entries.append(entry)
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func addModsToModpack(_ modpackID: UUID, mods modsToAdd: [Mod]) {
        guard let index = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        for mod in modsToAdd {
            // Mods are being explicitly added to this profile, so enable them. Update
            // an existing entry to enabled rather than skipping it.
            if let existingIdx = modpacks[index].entries.firstIndex(where: {
                $0.uniqueID.caseInsensitiveCompare(mod.id) == .orderedSame
            }) {
                modpacks[index].entries[existingIdx].isEnabled = true
            } else {
                modpacks[index].entries.append(ModpackEntry(mod: mod, isEnabled: true))
            }
        }
        persistModpacks()
    }

}
