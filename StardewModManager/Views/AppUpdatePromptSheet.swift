import SwiftUI

struct AppUpdatePromptSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.stardewOrange)

            Text(L.s("update_available"))
                .font(.stardew(size: 22))
                .foregroundStyle(Color.textDark)

            if let update = appState.availableUpdate {
                HStack(spacing: 8) {
                    Text("v\(currentVersion)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                    Text("v\(update.version)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.stardewOrange)
                }

                Text(L.s("update_version_message"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textMedium)
                    .multilineTextAlignment(.center)
            }

            if let error = appState.updateError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.stardewRed)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.stardewRed)
                        .lineLimit(2)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.stardewRed.opacity(0.08))
                )
            }

            Color.stardewDivider.opacity(0.3).frame(height: 1)

            if appState.isUpdating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L.s("update_downloading"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    // Update Now
                    Button {
                        appState.performAppUpdate()
                    } label: {
                        Text(L.s("update_now"))
                            .font(.stardew(size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.stardewGreen)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    // View on GitHub
                    if let update = appState.availableUpdate {
                        Button {
                            if let url = URL(string: update.htmlURL) {
                                NSWorkspace.shared.open(url)
                            }
                            dismiss()
                        } label: {
                            Text(L.s("update_view_github"))
                                .font(.stardew(size: 16))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentGold)
                                .foregroundStyle(Color.textDark)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }

                    // Later
                    Button {
                        dismiss()
                    } label: {
                        Text(L.s("update_later"))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color.parchment)
    }
}
