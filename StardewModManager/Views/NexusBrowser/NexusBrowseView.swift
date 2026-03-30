import SwiftUI

enum NexusBrowseTab: String, CaseIterable, Identifiable {
    case trending = "Trending"
    case latest = "Latest"
    case search = "Search"

    var id: String { rawValue }
}

struct NexusBrowseView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: NexusBrowseTab = .trending

    var body: some View {
        @Bindable var state = appState

        if !appState.settings.isAPIKeyValidated {
            NexusAPIKeySetupView()
        } else {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    StardewSegmentedPicker(
                        selection: $selectedTab,
                        label: { $0.rawValue }
                    )
                    .fixedSize()

                    Spacer()

                    Button {
                        refreshCurrentTab()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textMuted)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")

                    if let name = appState.settings.nexusUserName {
                        Label(name, systemImage: "person.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .padding()
                .background(Color.parchmentHeader)

                Color.frameBorder.frame(height: 2)

                // Search bar (only in search tab)
                if selectedTab == .search {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.textMuted)
                        TextField("Search Nexus Mods...", text: $state.nexusSearchText)
                            .textFieldStyle(.plain)
                            .font(.stardew(size: 16))
                            .onSubmit {
                                Task { await appState.searchNexusMods(query: appState.nexusSearchText) }
                            }

                        Button("Search") {
                            Task { await appState.searchNexusMods(query: appState.nexusSearchText) }
                        }
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentGold)
                        )
                        .buttonStyle(.plain)
                        .disabled(appState.nexusSearchText.isEmpty)
                        .opacity(appState.nexusSearchText.isEmpty ? 0.5 : 1)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.parchmentAlt)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.frameBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Content
                if appState.isNexusLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading...")
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = appState.nexusError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.stardewOrange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textLight)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            refreshCurrentTab()
                        }
                        .font(.stardew(size: 14))
                        .foregroundStyle(Color.textDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentGold)
                        )
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
                        ], spacing: 20) {
                            ForEach(currentMods) { mod in
                                NexusModCardView(mod: mod)
                                    .onTapGesture(count: 2) {
                                        appState.openNexusModPage(modId: mod.modId)
                                    }
                                    .onAppear {
                                        if mod.id == currentMods.last?.id {
                                            Task { await appState.loadMoreMods(tab: currentAppTab) }
                                        }
                                    }
                            }

                            if appState.isNexusLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color.parchment)
            .task(id: selectedTab) {
                appState.nexusHasMore = true
                switch selectedTab {
                case .trending:
                    if appState.nexusTrendingMods.isEmpty {
                        await appState.loadTrendingMods()
                    }
                case .latest:
                    if appState.nexusLatestMods.isEmpty {
                        await appState.loadLatestMods()
                    }
                case .search:
                    break
                }
            }
        }
    }

    private var currentMods: [NexusModInfo] {
        switch selectedTab {
        case .trending: return appState.nexusTrendingMods
        case .latest: return appState.nexusLatestMods
        case .search: return appState.nexusSearchResults
        }
    }

    private var currentAppTab: AppState.NexusTab {
        switch selectedTab {
        case .trending: return .trending
        case .latest: return .latest
        case .search: return .search
        }
    }

    private func refreshCurrentTab() {
        Task {
            appState.nexusError = nil
            switch selectedTab {
            case .trending:
                appState.nexusTrendingMods = []
                await appState.loadTrendingMods()
            case .latest:
                appState.nexusLatestMods = []
                await appState.loadLatestMods()
            case .search:
                if !appState.nexusSearchText.isEmpty {
                    await appState.searchNexusMods(query: appState.nexusSearchText)
                }
            }
        }
    }
}
