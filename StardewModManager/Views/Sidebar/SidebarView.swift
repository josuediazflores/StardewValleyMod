import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.sidebarSelection) {
            // Play Button
            Section {
                PlayButtonView()
            }

            // Navigation
            Section("Navigation") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }

            // Stats
            Section("Mods") {
                LabeledContent("Enabled", value: "\(appState.enabledCount)")
                LabeledContent("Disabled", value: "\(appState.disabledCount)")
                LabeledContent("Total", value: "\(appState.mods.count)")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Stardew Mod Manager")
    }
}
