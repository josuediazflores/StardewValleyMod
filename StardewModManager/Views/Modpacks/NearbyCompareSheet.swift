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
        .frame(width: 520, height: 520)
        .background(Color.parchment)
        .onDisappear {
            peerService.stopSearching()
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
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Modpack sent! Waiting for their modpack...")
                        .font(.stardew(size: 14))
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
                            }
                            if !onlyTheirs.isEmpty {
                                sectionHeader("They have, you don't", color: .stardewBlue)
                                ForEach(sortedNames(ids: onlyTheirs, myEntries: myModpack.entries, theirMods: theirModpack.mods), id: \.self) { name in
                                    modRow(name, color: .stardewBlue)
                                }
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
