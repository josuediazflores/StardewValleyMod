import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 0) {
            Text("NAVIGATION")
                .font(.stardew(size: 13))
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(SidebarItem.allCases, id: \.self) { item in
                Button {
                    appState.sidebarSelection = item
                } label: {
                    HStack(spacing: 8) {
                        stardewIcon(for: item)
                        Text(item.rawValue)
                            .font(.stardew(size: 16))
                            .lineLimit(1)
                        Spacer()
                        if item == .myMods && appState.mods.count > 0 {
                            Text("\(appState.mods.count)")
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        appState.sidebarSelection == item
                            ? Color.accentGold.opacity(0.25)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            Spacer()
        }
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
