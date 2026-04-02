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
                        Text(item.displayName)
                            .font(.stardew(size: 17))
                            .lineLimit(1)
                        Spacer()
                        if item == .modpacks {
                            Text("\(appState.modpacks.count)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.accentGold.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(Color.accentGold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        if item == .installedMods {
                            if !appState.modUpdates.isEmpty {
                                Text("\(appState.modUpdates.count)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.stardewOrange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .background(Color.stardewOrange.opacity(0.2))
                                    .clipShape(Capsule())
                            } else {
                                Text("\(appState.userModCount)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.accentGold.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .background(Color.accentGold.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.sidebarSelection == item
                                ? Color.accentGold.opacity(0.25)
                                : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.sidebarSelection == item
                                ? Color.frameBorder
                                : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            // Settings & Status (pinned to bottom)
            VStack(spacing: 8) {
                Color.frameBorder
                    .frame(height: 2)

                if let update = appState.availableUpdate {
                    Button {
                        if let url = URL(string: update.htmlURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                            Text(L.s("settings_update_available", update.version))
                                .font(.stardew(size: 13))
                        }
                        .foregroundStyle(Color.stardewOrange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    openSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                        Text(L.s("sidebar_settings"))
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
                    Text(appState.settings.isSMAPIInstalled ? L.s("sidebar_smapi_ready") : L.s("sidebar_smapi_not_found"))
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
        .overlay(alignment: .trailing) {
            Color.frameBorder
                .frame(width: 3)
                .ignoresSafeArea()
        }
        .foregroundStyle(Color.accentGold)
        .tint(.accentGold)
        .navigationTitle("")
    }

    @ViewBuilder
    private func stardewIcon(for item: SidebarItem) -> some View {
        switch item {
        case .modpacks:
            if let url = Bundle.appBundle.url(forResource: "Golden_Scroll", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
            } else {
                StardewIcon(type: .chest, size: 20)
            }
        case .browseNexus:
            if let url = Bundle.appBundle.url(forResource: "Horse_The_Book", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
            } else {
                StardewIcon(type: .globe, size: 20)
            }
        case .installedMods:
            if let url = Bundle.appBundle.url(forResource: "Robins_Hammer", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 20, height: 20)
            } else {
                StardewIcon(type: .chest, size: 20)
            }
        }
    }
}
