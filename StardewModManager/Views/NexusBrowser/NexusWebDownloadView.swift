import SwiftUI

struct NexusWebDownloadView: View {
    let modName: String
    let url: URL
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modName)
                        .font(.stardew(size: 20))
                        .foregroundStyle(Color.textDark)
                        .lineLimit(1)

                    Text("Log in if needed, then click \"Mod Manager Download\"")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.parchmentHeader)

            Color.frameBorder.frame(height: 2)

            // Web view
            NexusWebView(url: url, isLoading: $isLoading) { nxmURL in
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.handleNXMLink(nxmURL)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color.parchment)
    }
}
