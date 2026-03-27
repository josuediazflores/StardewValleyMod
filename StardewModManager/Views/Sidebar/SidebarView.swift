import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.sidebarSelection) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label {
                        Text(item.rawValue)
                            .font(.stardew(size: 16))
                    } icon: {
                        stardewIcon(for: item)
                    }
                    .tag(item)
                    .badge(item == .myMods ? appState.mods.count : 0)
                }
            } header: {
                Text("NAVIGATION")
                    .font(.stardew(size: 13))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(colors: [.sidebarWoodLight, .sidebarWood],
                           startPoint: .top, endPoint: .bottom)
        )
        .foregroundStyle(Color.accentGold)
        .tint(.accentGold)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                    .frame(width: 8, height: 8)
                Text(appState.settings.isSMAPIInstalled ? "SMAPI Ready" : "SMAPI Not Found")
                    .font(.stardew(size: 13))
                    .foregroundStyle(Color.textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarWood)
        }
        .navigationTitle("Stardew Mod Manager")
    }

    @ViewBuilder
    private func stardewIcon(for item: SidebarItem) -> some View {
        switch item {
        case .myMods:
            StardewIcon(type: .chest, size: 18)
        case .modpacks:
            StardewIcon(type: .scroll, size: 18)
        case .browseNexus:
            StardewIcon(type: .globe, size: 18)
        case .importMods:
            StardewIcon(type: .arrowBox, size: 18)
        }
    }
}
