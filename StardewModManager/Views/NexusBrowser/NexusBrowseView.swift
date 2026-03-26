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
    @State private var selectedNexusMod: NexusModInfo?

    var body: some View {
        @Bindable var state = appState

        if !appState.settings.isAPIKeyValidated {
            NexusAPIKeySetupView()
        } else {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Picker("", selection: $selectedTab) {
                        ForEach(NexusBrowseTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    Spacer()

                    if let name = appState.settings.nexusUserName {
                        Label(name, systemImage: "person.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                // Search bar (only in search tab)
                if selectedTab == .search {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search Nexus Mods...", text: $state.nexusSearchText)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                Task { await appState.searchNexusMods(query: appState.nexusSearchText) }
                            }
                        Button("Search") {
                            Task { await appState.searchNexusMods(query: appState.nexusSearchText) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(appState.nexusSearchText.isEmpty)
                    }
                    .padding(8)
                    .background(.bar)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Content
                if appState.isNexusLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = appState.nexusError {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                        ], spacing: 16) {
                            ForEach(currentMods) { mod in
                                NexusModCardView(mod: mod)
                                    .onTapGesture {
                                        selectedNexusMod = mod
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .sheet(item: $selectedNexusMod) { mod in
                NexusModDetailView(mod: mod)
                    .environment(appState)
            }
            .task(id: selectedTab) {
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
}
