import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 2) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                Button {
                    appState.sidebarSelection = item
                } label: {
                    HStack(spacing: 10) {
                        stardewIcon(for: item)
                        Text(item.rawValue)
                            .font(.stardew(size: 17))
                            .lineLimit(1)
                        Spacer()
                        if item == .modpacks {
                            Text("\(appState.modpacks.count + 1)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.accentGold.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentGold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.sidebarSelection == item
                                ? Color.accentGold.opacity(0.2)
                                : Color.clear)
                    )
                    .overlay(alignment: .leading) {
                        if appState.sidebarSelection == item {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentGold)
                                .frame(width: 3)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            // Settings & Status (pinned to bottom)
            VStack(spacing: 8) {
                Color.accentGold.opacity(0.2)
                    .frame(height: 1)

                Button {
                    openSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.stardew(size: 15))
                    }
                    .foregroundStyle(Color.accentGold.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.settings.isSMAPIInstalled ? Color.stardewGreen : Color.stardewRed)
                        .frame(width: 7, height: 7)
                    Text(appState.settings.isSMAPIInstalled ? "SMAPI Ready" : "SMAPI Not Found")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentGold.opacity(0.5))
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .padding(.top, 36)
        .background(
            LinearGradient(colors: [.sidebarWoodLight, .sidebarWood],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .foregroundStyle(Color.accentGold)
        .tint(.accentGold)
        .navigationTitle("")
    }

    @ViewBuilder
    private func stardewIcon(for item: SidebarItem) -> some View {
        switch item {
        case .modpacks:
            if let url = Bundle.module.url(forResource: "Golden_Scroll", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
            } else {
                StardewIcon(type: .chest, size: 20)
            }
        case .browseNexus:
            if let url = Bundle.module.url(forResource: "Horse_The_Book", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
            } else {
                StardewIcon(type: .globe, size: 20)
            }
        case .importMods:
            StardewIcon(type: .arrowBox, size: 20)
        }
    }
}
