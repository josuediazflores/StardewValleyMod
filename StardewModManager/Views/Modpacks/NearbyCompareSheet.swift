import SwiftUI

struct NearbyCompareSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var peerService = PeerSyncService()
    @State private var selectedModpack: Modpack?
    @State private var hasSent = false

    var body: some View {
        VStack(spacing: 16) {
            Text(L.s("nearby_title"))
                .font(.stardew(size: 22))
                .foregroundStyle(Color.textDark)

            if peerService.transferState != .idle {
                transferView
            } else {
                switch peerService.connectionState {
                case .idle, .searching:
                    searchingView
                case .connected(let peerName):
                    connectedView(peerName: peerName)
                case .received:
                    resultsView
                case .error(let message):
                    Text(message)
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.stardewRed)
                }
            }

            Spacer()

            Button(L.s("nearby_close")) {
                peerService.stopSearching()
                dismiss()
            }
            .font(.stardew(size: 16))
            .buttonStyle(.plain)
            .foregroundStyle(Color.textMuted)
        }
        .padding(24)
        .frame(width: 520, height: 560)
        .background(Color.parchment)
        .onDisappear {
            peerService.stopSearching()
        }
        .onAppear {
            peerService.onModsReceived = { [weak appState] zipURL in
                guard let appState else { return }
                Task { @MainActor in
                    appState.importMods(from: [zipURL])
                    try? FileManager.default.removeItem(at: zipURL)

                    // Save the modpack config as a profile if metadata was received
                    if let received = peerService.receivedModpack {
                        let newModpack = received.toModpack()
                        if !appState.modpacks.contains(where: { $0.name == newModpack.name }) {
                            appState.modpacks.append(newModpack)
                            try? ModpackService.saveModpacks(appState.modpacks, settings: appState.settings)
                        }
                    }

                    let importedCount = appState.mods.count
                    peerService.transferState = .complete(importedCount)
                    SoundService.play(.bigSelect)
                }
            }
        }
    }

    // MARK: - Searching State

    private var searchingView: some View {
        VStack(spacing: 16) {
            // Modpack picker
            VStack(alignment: .leading, spacing: 4) {
                Text(L.s("nearby_select_modpack"))
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
                Picker("", selection: $selectedModpack) {
                    Text(L.s("compare_select")).tag(nil as Modpack?)
                    ForEach(appState.modpacks) { mp in
                        Text(mp.name).tag(mp as Modpack?)
                    }
                }
                .labelsHidden()
            }

            if selectedModpack != nil {
                if !peerService.isSearching {
                    Button {
                        peerService.startSearching()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 12))
                            Text(L.s("nearby_start"))
                                .font(.stardew(size: 16))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.stardewBlue)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(L.s("nearby_searching"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)

                        if peerService.foundPeers.isEmpty {
                            Text(L.s("nearby_ensure"))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted.opacity(0.7))
                                .multilineTextAlignment(.center)
                        } else {
                            VStack(spacing: 6) {
                                Text(L.s("nearby_found"))
                                    .font(.stardew(size: 13))
                                    .foregroundStyle(Color.textMuted)
                                ForEach(peerService.foundPeers, id: \.self) { peer in
                                    Button {
                                        peerService.connectToPeer(peer)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "laptopcomputer")
                                                .font(.system(size: 12))
                                            Text(peer.displayName)
                                                .font(.stardew(size: 15))
                                        }
                                        .foregroundStyle(Color.textDark)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.parchmentAlt)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color.frameBorder, lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            } else {
                Text(L.s("nearby_pick_first"))
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
            }
        }
    }

    // MARK: - Connected State

    private func connectedView(peerName: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.stardewGreen)
                Text(L.s("nearby_connected", peerName))
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.stardewGreen)
            }

            if !hasSent {
                VStack(spacing: 12) {
                    Button {
                        if let modpack = selectedModpack {
                            let shareable = ShareableModpack.from(modpack)
                            peerService.sendModpack(shareable)
                            hasSent = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                            Text(L.s("nearby_send"))
                                .font(.stardew(size: 16))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.stardewGreen)
                        )
                    }
                    .buttonStyle(.plain)

                    // Send full modpack with files
                    Button {
                        sendFullModpack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 12))
                            Text(L.s("nearby_send_full"))
                                .font(.stardew(size: 14))
                        }
                        .foregroundStyle(Color.stardewBlue)
                    }
                    .buttonStyle(.plain)
                    .help(L.s("nearby_send_full_help"))
                }
            } else if peerService.receivedModpack != nil {
                // They sent theirs too — jump to results
                Button {
                    peerService.connectionState = .received
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                        Text(L.s("nearby_compare"))
                            .font(.stardew(size: 16))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.stardewBlue)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.stardewGreen)
                    Text(L.s("nearby_sent"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.stardewGreen)
                    Text(L.s("nearby_waiting"))
                        .font(.stardew(size: 13))
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
    }

    // MARK: - Results State

    @ViewBuilder
    private var resultsView: some View {
        if let myModpack = selectedModpack, let theirModpack = peerService.receivedModpack {
            let myMods = Set(myModpack.entries.filter(\.isEnabled).map(\.uniqueID))
            let theirMods = Set(theirModpack.mods.map(\.uniqueID))
            let inBoth = myMods.intersection(theirMods)
            let onlyMine = myMods.subtracting(theirMods)
            let onlyTheirs = theirMods.subtracting(myMods)

            VStack(spacing: 12) {
                if onlyMine.isEmpty && onlyTheirs.isEmpty {
                    // Perfect match
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.stardewGreen)
                        Text(L.s("nearby_perfect_match"))
                            .font(.stardew(size: 20))
                            .foregroundStyle(Color.stardewGreen)
                        Text(L.s("nearby_all_match", inBoth.count))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    }
                } else {
                    // Mismatch summary
                    HStack(spacing: 20) {
                        Label(L.s("nearby_shared", inBoth.count), systemImage: "checkmark.circle")
                            .foregroundStyle(Color.stardewGreen)
                        Label(L.s("nearby_only_you", onlyMine.count), systemImage: "person")
                            .foregroundStyle(Color.stardewOrange)
                        Label(L.s("nearby_only_them", onlyTheirs.count), systemImage: "person.2")
                            .foregroundStyle(Color.stardewBlue)
                    }
                    .font(.stardew(size: 13))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if !onlyMine.isEmpty {
                                sectionHeader(L.s("nearby_you_have"), color: .stardewOrange)
                                ForEach(sortedNames(ids: onlyMine, myEntries: myModpack.entries, theirMods: theirModpack.mods), id: \.self) { name in
                                    modRow(name, color: .stardewOrange)
                                }

                                // Send missing mods button
                                Button {
                                    sendMissingMods(ids: onlyMine, from: myModpack)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 11))
                                        Text(L.s("nearby_send_missing", onlyMine.count))
                                            .font(.stardew(size: 14))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.stardewGreen)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 6)
                            }
                            if !onlyTheirs.isEmpty {
                                sectionHeader(L.s("nearby_they_have"), color: .stardewBlue)
                                ForEach(sortedNames(ids: onlyTheirs, myEntries: myModpack.entries, theirMods: theirModpack.mods), id: \.self) { name in
                                    modRow(name, color: .stardewBlue)
                                }

                                Text(L.s("nearby_ask_friend"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textMuted.opacity(0.7))
                                    .padding(.top, 4)
                            }
                            if !inBoth.isEmpty {
                                sectionHeader(L.s("nearby_matched", inBoth.count), color: .stardewGreen)
                                ForEach(sortedNames(ids: inBoth, myEntries: myModpack.entries, theirMods: theirModpack.mods), id: \.self) { name in
                                    modRow(name, color: .stardewGreen)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    // MARK: - Transfer Progress View

    private var transferView: some View {
        VStack(spacing: 20) {
            switch peerService.transferState {
            case .zipping:
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L.s("nearby_preparing"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                }

            case .sending:
                VStack(spacing: 16) {
                    Text(L.s("nearby_sending"))
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)
                    StardewProgressBar(
                        progress: peerService.transferProgress,
                        label: "\(Int(peerService.transferProgress * 100))%"
                    )
                    Text(L.s("nearby_keep_near"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                }

            case .receiving:
                VStack(spacing: 16) {
                    Text(L.s("nearby_receiving"))
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)
                    StardewProgressBar(
                        progress: peerService.transferProgress,
                        label: "\(Int(peerService.transferProgress * 100))%"
                    )
                    Text(L.s("nearby_keep_near"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                }

            case .importing:
                VStack(spacing: 12) {
                    ProgressView()
                    Text(L.s("nearby_importing"))
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                }

            case .complete(let count):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.stardewGreen)
                    Text(L.s("nearby_transfer_done"))
                        .font(.stardew(size: 20))
                        .foregroundStyle(Color.stardewGreen)
                    if count > 0 {
                        Text(L.s("nearby_mods_imported"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    } else {
                        Text(L.s("nearby_mods_sent"))
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    }
                }

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.stardewRed)
                    Text(L.s("nearby_transfer_failed"))
                        .font(.stardew(size: 20))
                        .foregroundStyle(Color.stardewRed)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                        .multilineTextAlignment(.center)
                }

            case .idle:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transfer Actions

    private func sendMissingMods(ids: Set<String>, from modpack: Modpack) {
        let modsToSend = appState.mods.filter { ids.contains($0.id) }
        guard !modsToSend.isEmpty else { return }
        zipAndSend(modsToSend)
    }

    private func sendFullModpack() {
        guard let modpack = selectedModpack else { return }

        // Always send metadata first so receiver gets the enable/disable config
        let shareable = ShareableModpack.from(modpack)
        peerService.sendModpack(shareable)
        hasSent = true

        let enabledIDs = Set(modpack.entries.filter(\.isEnabled).map(\.uniqueID))

        // If we know what the receiver has, only send what they're missing
        let idsToSend: Set<String>
        if let theirModpack = peerService.receivedModpack {
            let theirIDs = Set(theirModpack.mods.map(\.uniqueID))
            idsToSend = enabledIDs.subtracting(theirIDs)
        } else {
            idsToSend = enabledIDs
        }

        let modsToSend = appState.mods.filter { idsToSend.contains($0.id) }
        guard !modsToSend.isEmpty else {
            // They already have everything, just show complete
            peerService.transferState = .complete(0)
            return
        }
        zipAndSend(modsToSend)
    }

    private func zipAndSend(_ mods: [Mod]) {
        peerService.transferState = .zipping

        // Capture folder info for background thread (avoid sending Mod across threads)
        let modFolders = mods.map { (folderName: $0.folderName, folderURL: $0.folderURL) }

        Task {
            do {
                let zipURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let url = try ModpackService.zipModFolders(modFolders)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                peerService.sendMods(zipURL: zipURL)
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    try? FileManager.default.removeItem(at: zipURL)
                }
            } catch {
                peerService.transferState = .error("Failed to prepare mods: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func sortedNames(ids: Set<String>, myEntries: [ModpackEntry], theirMods: [ShareableModpack.ShareableModpackMod]) -> [String] {
        let myMap = Dictionary(myEntries.map { ($0.uniqueID, $0.name) }, uniquingKeysWith: { a, _ in a })
        let theirMap = Dictionary(theirMods.map { ($0.uniqueID, $0.name) }, uniquingKeysWith: { a, _ in a })
        return ids.map { myMap[$0] ?? theirMap[$0] ?? $0 }.sorted()
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

// MARK: - Progress Bar

private struct StardewProgressBar: View {
    let progress: Double
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.parchmentAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.frameBorder, lineWidth: 2)
                        )

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.stardewGreen)
                        .frame(width: max(0, (geo.size.width - 4) * progress))
                        .padding(2)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 24)
            .frame(maxWidth: 350)

            Text(label)
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textMedium)
        }
    }
}
