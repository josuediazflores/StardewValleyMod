import Foundation
import SwiftUI

extension AppState {

    // MARK: - Mod Toggle / Enable & Disable

    func toggleMod(_ mod: Mod) -> DependencyWarning? {
        if mod.isEnabled {
            return checkAndDisableMod(mod)
        } else {
            return checkAndEnableMod(mod)
        }
    }

    func checkAndDisableMod(_ mod: Mod) -> DependencyWarning? {
        return DependencyResolver.checkDisableImpact(mod: mod, allMods: mods)
    }

    func checkAndEnableMod(_ mod: Mod) -> DependencyWarning? {
        return DependencyResolver.checkEnableRequirements(mod: mod, allMods: mods)
    }

    func performEnableMod(_ mod: Mod) {
        do {
            try ModManagementService.enableMod(mod, settings: settings)
            pruneStaleDuplicates(of: mod)
            DependencyResolver.resolveAll(mods: mods)
            syncActiveModpackEntry(mod: mod, isEnabled: true)
            showToast("\(mod.manifest.name) enabled", type: .success)
            SoundService.play(.click)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performDisableMod(_ mod: Mod) {
        do {
            try ModManagementService.disableMod(mod, settings: settings)
            pruneStaleDuplicates(of: mod)
            DependencyResolver.resolveAll(mods: mods)
            syncActiveModpackEntry(mod: mod, isEnabled: false)
            showToast("\(mod.manifest.name) disabled", type: .info)
            SoundService.play(.click)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Keeps the active modpack in sync when a mod is toggled from the Mods tab
    private func syncActiveModpackEntry(mod: Mod, isEnabled: Bool) {
        guard let activeID = activeModpackID,
              let idx = modpacks.firstIndex(where: { $0.id == activeID }) else { return }

        if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == mod.id }) {
            modpacks[idx].entries[entryIdx].isEnabled = isEnabled
        } else {
            modpacks[idx].entries.append(ModpackEntry(mod: mod, isEnabled: isEnabled))
        }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    // MARK: - Import

    /// Imports mods off the main thread so a large (hundreds-of-MB) archive can't
    /// beachball the UI: the heavy extraction + recursive copy run on a detached
    /// executor and `mods` is only mutated back on the MainActor after each await.
    func importMods(from urls: [URL]) {
        guard !isImporting else { return }

        // A source that lives in our own temp dir (e.g. a peer-transfer zip) can be
        // deleted by the caller the instant this method returns, which would race the
        // background read. Take ownership of those synchronously with an O(1) move so
        // the detached import reads a copy the caller can't pull out from under it.
        // User-picked files are left in place and read under a held security scope;
        // their callers never delete them.
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.resolvingSymlinksInPath().path(percentEncoded: false)
        var sources: [(url: URL, isOwnedCopy: Bool)] = []
        for url in urls {
            let resolved = url.resolvingSymlinksInPath().path(percentEncoded: false)
            if resolved.hasPrefix(tempBase) {
                let staged = fm.temporaryDirectory.appending(path: "import_\(UUID().uuidString)_\(url.lastPathComponent)")
                if (try? fm.moveItem(at: url, to: staged)) != nil {
                    sources.append((staged, true))
                    continue
                }
            }
            sources.append((url, false))
        }

        isImporting = true
        isLoading = true
        let currentSettings = settings
        Task {
            defer {
                isImporting = false
                isLoading = false
            }
            var allImported: [Mod] = []
            var allFailures: [ImportFailure] = []
            for source in sources {
                let url = source.url
                let securityScoped = url.startAccessingSecurityScopedResource()
                do {
                    let existing = mods
                    let result = try await Task.detached(priority: .userInitiated) {
                        try ModManagementService.importMod(from: url, settings: currentSettings, existingMods: existing)
                    }.value
                    for newMod in result.mods {
                        mods.removeAll { $0.id == newMod.id }
                        mods.append(newMod)
                        allImported.append(newMod)
                    }
                    allFailures.append(contentsOf: result.failures)
                } catch {
                    errorMessage = error.localizedDescription
                }
                if securityScoped { url.stopAccessingSecurityScopedResource() }
                if source.isOwnedCopy { try? fm.removeItem(at: source.url) }
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            addNewModsToActiveModpack(allImported)
            if !allImported.isEmpty {
                showToast("Imported \(allImported.count) mod\(allImported.count == 1 ? "" : "s")", type: .success)
                SoundService.play(.bigSelect)
            }
            if !allFailures.isEmpty {
                let names = allFailures.prefix(3).map(\.name).joined(separator: ", ")
                let suffix = allFailures.count > 3 ? ", …" : ""
                showToast("\(allFailures.count) mod\(allFailures.count == 1 ? "" : "s") failed to import: \(names)\(suffix)", type: .warning)
            }
        }
    }

    /// Auto-adds newly installed mods to the active modpack, recording each mod's
    /// actual on-disk enabled state (imported mods install enabled).
    func addNewModsToActiveModpack(_ newMods: [Mod]) {
        guard !newMods.isEmpty, let activeID = activeModpackID,
              let idx = modpacks.firstIndex(where: { $0.id == activeID }) else { return }
        for mod in newMods {
            guard !modpacks[idx].entries.contains(where: { $0.uniqueID == mod.id }) else { continue }
            let entry = ModpackEntry(mod: mod, isEnabled: mod.isEnabled)
            modpacks[idx].entries.append(entry)
        }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    // MARK: - Soft Delete (with Undo)

    func softDeleteMod(_ mod: Mod) {
        softDeleteMods([mod])
    }

    func softDeleteMods(_ modsToDelete: [Mod]) {
        let deletionID = UUID()
        var originalURLs: [URL] = []
        var wasEnabled: [Bool] = []
        var stagingURLs: [URL] = []
        var deletedMods: [Mod] = []

        for mod in modsToDelete {
            do {
                let stagingURL = try ModManagementService.trashMod(mod)
                originalURLs.append(mod.folderURL)
                wasEnabled.append(mod.isEnabled)
                stagingURLs.append(stagingURL)
                deletedMods.append(mod)

                // Drop only the trashed on-disk instance; a same-ID duplicate copy
                // (a supported state) at a different path must survive.
                mods.removeAll { $0.folderURL == mod.folderURL }
                if selectedModID == mod.id { selectedModID = nil }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        guard !deletedMods.isEmpty else { return }

        // Capture the modpack entries about to be stripped so undo can put them back.
        let deletedIDs = deletedMods.map(\.id)
        var removedEntries: [(modpackID: UUID, entry: ModpackEntry)] = []
        for modpack in modpacks {
            for entry in modpack.entries
            where deletedIDs.contains(where: { $0.caseInsensitiveCompare(entry.uniqueID) == .orderedSame }) {
                removedEntries.append((modpackID: modpack.id, entry: entry))
            }
        }

        for mod in deletedMods {
            removeModFromAllModpacks(mod.id)
        }
        DependencyResolver.resolveAll(mods: mods)

        let pending = PendingDeletion(
            id: deletionID,
            mods: deletedMods,
            originalURLs: originalURLs,
            wasEnabled: wasEnabled,
            stagingURLs: stagingURLs,
            removedEntries: removedEntries
        )
        pendingDeletions.append(pending)

        let modNames = deletedMods.count == 1
            ? deletedMods[0].manifest.name
            : "\(deletedMods.count) mods"

        showToast("\(modNames) deleted", type: .warning) { [weak self] in
            self?.undoDelete(id: deletionID)
        }
        SoundService.play(.warning)

        // Finalize when toast expires
        Task {
            try? await Task.sleep(for: .seconds(6.0))
            finalizeDeletion(id: deletionID)
        }
    }

    func undoDelete(id: UUID) {
        guard let pendingIndex = pendingDeletions.firstIndex(where: { $0.id == id }) else { return }
        let pending = pendingDeletions[pendingIndex]

        for i in pending.mods.indices {
            let mod = pending.mods[i]
            let targetURL = pending.originalURLs[i]

            do {
                let restoredURL = try ModManagementService.restoreFromTrash(stagingURL: pending.stagingURLs[i], to: targetURL)
                mod.folderURL = restoredURL
                mod.folderName = restoredURL.lastPathComponent
                mod.isEnabled = pending.wasEnabled[i]
                mods.append(mod)
            } catch {
                errorMessage = "Failed to restore \(mod.manifest.name): \(error.localizedDescription)"
            }
        }

        mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        DependencyResolver.resolveAll(mods: mods)

        // Restore the modpack membership that softDeleteMods stripped, guarding
        // against modpacks that no longer exist and against re-adding duplicates.
        var modpacksChanged = false
        for removed in pending.removedEntries {
            guard let idx = modpacks.firstIndex(where: { $0.id == removed.modpackID }) else { continue }
            if !modpacks[idx].entries.contains(where: { $0.uniqueID.caseInsensitiveCompare(removed.entry.uniqueID) == .orderedSame }) {
                modpacks[idx].entries.append(removed.entry)
                modpacks[idx].updatedAt = Date()
                modpacksChanged = true
            }
        }
        if modpacksChanged {
            persistModpacks()
        }

        pendingDeletions.remove(at: pendingIndex)

        let restoredName = pending.mods.count == 1
            ? pending.mods[0].manifest.name
            : "\(pending.mods.count) mods"
        showToast("Restored \(restoredName)", type: .success)
        SoundService.play(.click)
    }

    func finalizeDeletion(id: UUID) {
        guard let pendingIndex = pendingDeletions.firstIndex(where: { $0.id == id }) else { return }
        let pending = pendingDeletions[pendingIndex]
        ModManagementService.emptyTrash(stagingURLs: pending.stagingURLs)
        pendingDeletions.remove(at: pendingIndex)
    }

    // MARK: - Batch Operations

    func batchEnableMods(_ ids: Set<String>) {
        var enabledCount = 0
        var failedCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), !mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                try ModManagementService.enableMod(mod, settings: settings)
                pruneStaleDuplicates(of: mod)
                syncActiveModpackEntry(mod: mod, isEnabled: true)
                enabledCount += 1
            } catch { failedCount += 1 }
        }
        DependencyResolver.resolveAll(mods: mods)
        if failedCount > 0 {
            showToast("\(failedCount) mod\(failedCount == 1 ? "" : "s") failed to enable", type: .warning)
        } else if enabledCount > 0 {
            showToast("\(enabledCount) mod\(enabledCount == 1 ? "" : "s") enabled", type: .success)
            SoundService.play(.bigSelect)
        }
    }

    func batchDisableMods(_ ids: Set<String>) {
        var disabledCount = 0
        var failedCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                try ModManagementService.disableMod(mod, settings: settings)
                pruneStaleDuplicates(of: mod)
                // Sync only after the disk move succeeds, mirroring batchEnableMods,
                // so a failed move can't leave the profile recording a wrong state.
                syncActiveModpackEntry(mod: mod, isEnabled: false)
                disabledCount += 1
            } catch { failedCount += 1 }
        }
        DependencyResolver.resolveAll(mods: mods)
        if failedCount > 0 {
            showToast("\(failedCount) mod\(failedCount == 1 ? "" : "s") failed to disable", type: .warning)
        } else if disabledCount > 0 {
            showToast("\(disabledCount) mod\(disabledCount == 1 ? "" : "s") disabled", type: .info)
            SoundService.play(.bigSelect)
        }
    }

}
