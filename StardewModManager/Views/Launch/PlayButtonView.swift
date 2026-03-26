import SwiftUI

struct PlayButtonView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 8) {
            Button {
                appState.launchGame()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Play")
                        .font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!appState.settings.isSMAPIInstalled)

            if appState.settings.isSMAPIInstalled {
                Text("SMAPI Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("SMAPI Not Found")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
