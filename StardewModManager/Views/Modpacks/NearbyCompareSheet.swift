import SwiftUI

struct NearbyCompareSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var peerService = PeerSyncService()
    @State private var selectedModpack: Modpack?
    @State private var hasSent = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Compare with Nearby Player")
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

            Button("Close") {
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
                    let count = appState.mods.count
                    peerService.transferState = .complete(count)
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
                Text("Select your modpack to compare:")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
                Picker("", selection: $selectedModpack) {
                    Text("Select...").tag(nil as Modpack?)
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
                            Text("Start Searching")
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
                        Text("Looking for nearby players...")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)

                        if peerService.foundPeers.isEmpty {
                            Text("Make sure the other player also has Compare Nearby open")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted.opacity(0.7))
                                .multilineTextAlignment(.center)
                        } else {
                            VStack(spacing: 6) {
                                Text("Found nearby:")
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
                Text("Pick a modpack first")
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
                Text("Connected to \(peerName)")
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
                            Text("Send My Modpack")
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
                            Text("Send Full Modpack with Files")
                                .font(.stardew(size: 14))
                        }
                        .foregroundStyle(Color.stardewBlue)
                    }
                    .buttonStyle(.plain)
                    .help("Send all mod files so your friend can install them")
                }
            } else if peerService.receivedModpack != nil {
                // They sent theirs too — jump to results
                Button {
                    peerService.connectionState = .received
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                        Text("Compare Modpacks")
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
                    Text("Modpack sent!")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.stardewGreen)
                    Text("Waiting for their modpack to compare...")
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
                        Text("Perfect Match!")
                            .font(.stardew(size: 20))
                            .foregroundStyle(Color.stardewGreen)
                        Text("All \(inBoth.count) enabled mods match.")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    }
                } else {
                    // Mismatch summary
                    HStack(spacing: 20) {
                        Label("\(inBoth.count) shared", systemImage: "checkmark.circle")
                            .foregroundStyle(Color.stardewGreen)
                        Label("\(onlyMine.count) only you", systemImage: "person")
                            .foregroundStyle(Color.stardewOrange)
                        Label("\(onlyTheirs.count) only them", systemImage: "person.2")
                            .foregroundStyle(Color.stardewBlue)
                    }
                    .font(.stardew(size: 13))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if !onlyMine.isEmpty {
                                sectionHeader("You have, they don't", color: .stardewOrange)
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
                                        Text("Send \(onlyMine.count) Missing Mod\(onlyMine.count == 1 ? "" : "s")")
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
                                sectionHeader("They have, you don't", color: .stardewBlue)
                                ForEach(sortedNames(ids: onlyTheirs, myEntries: myModpack.entries, theirMods: theirModpack.mods), id: \.self) { name in
                                    modRow(name, color: .stardewBlue)
                                }

                                Text("Ask your friend to send these from their side")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textMuted.opacity(0.7))
                                    .padding(.top, 4)
                            }
                            if !inBoth.isEmpty {
                                sectionHeader("Matched (\(inBoth.count))", color: .stardewGreen)
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
                    Text("Preparing mods...")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                }

            case .sending:
                VStack(spacing: 16) {
                    Text("Sending mods...")
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)
                    StardewProgressBar(
                        progress: peerService.transferProgress,
                        label: "\(Int(peerService.transferProgress * 100))%"
                    )
                    Text("Keep both devices nearby")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                }

            case .receiving:
                VStack(spacing: 16) {
                    Text("Receiving mods...")
                        .font(.stardew(size: 18))
                        .foregroundStyle(Color.textDark)
                    StardewProgressBar(
                        progress: peerService.transferProgress,
                        label: "\(Int(peerService.transferProgress * 100))%"
                    )
                    Text("Keep both devices nearby")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textMuted.opacity(0.7))
                }

            case .importing:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Importing mods...")
                        .font(.stardew(size: 16))
                        .foregroundStyle(Color.textMuted)
                }

            case .complete(let count):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.stardewGreen)
                    Text("Transfer Complete!")
                        .font(.stardew(size: 20))
                        .foregroundStyle(Color.stardewGreen)
                    if count > 0 {
                        Text("Mods imported successfully.")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    } else {
                        Text("Mods sent successfully.")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.textMuted)
                    }
                }

            case .error(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.stardewRed)
                    Text("Transfer Failed")
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

        peerService.transferState = .zipping

        Task {
            do {
                let zipURL = try ModpackService.zipMods(modsToSend)
                peerService.sendMods(zipURL: zipURL)
                // Clean up ZIP after send completes
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    try? FileManager.default.removeItem(at: zipURL)
                }
            } catch {
                peerService.transferState = .error("Failed to prepare mods: \(error.localizedDescription)")
            }
        }
    }

    private func sendFullModpack() {
        guard let modpack = selectedModpack else { return }
        let enabledIDs = Set(modpack.entries.filter(\.isEnabled).map(\.uniqueID))
        let modsToSend = appState.mods.filter { enabledIDs.contains($0.id) }
        guard !modsToSend.isEmpty else { return }

        peerService.transferState = .zipping

        Task {
            do {
                let zipURL = try ModpackService.zipMods(modsToSend)
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
