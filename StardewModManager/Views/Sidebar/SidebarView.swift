import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.sidebarSelection) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    HStack(spacing: 10) {
                        stardewIcon(for: item)
                        Text(item.rawValue)
                            .font(.stardew(size: 18))
                        Spacer()
                        if item == .myMods && appState.mods.count > 0 {
                            Text("\(appState.mods.count)")
                                .font(.stardew(size: 14))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(Color.sidebarWoodDark)
                                .foregroundStyle(Color.accentGold)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .tag(item)
                    .listRowBackground(
                        appState.sidebarSelection == item
                            ? AnyView(
                                LinearGradient(colors: [.accentGold, Color(red: 0.77, green: 0.58, blue: 0.31)],
                                               startPoint: .leading, endPoint: .trailing)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                              )
                            : AnyView(Color.clear)
                    )
                    .foregroundStyle(appState.sidebarSelection == item ? Color.textDark : Color(red: 0.77, green: 0.58, blue: 0.42))
                }
            } header: {
                Text("Navigation")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(colors: [.sidebarWoodLight, .sidebarWood],
                           startPoint: .top, endPoint: .bottom)
        )
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                    .frame(width: 8, height: 8)
                Text(appState.settings.isSMAPIInstalled ? "SMAPI Ready" : "SMAPI Not Found")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.sidebarWood)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.sidebarWoodLight).frame(height: 1)
            }
        }
        .navigationTitle("Stardew Mod Manager")
    }

    @ViewBuilder
    private func stardewIcon(for item: SidebarItem) -> some View {
        switch item {
        case .myMods:
            StardewIcon(type: .chest, size: 20)
        case .modpacks:
            StardewIcon(type: .scroll, size: 20)
        case .browseNexus:
            StardewIcon(type: .globe, size: 20)
        case .importMods:
            StardewIcon(type: .arrowBox, size: 20)
        }
    }
}
