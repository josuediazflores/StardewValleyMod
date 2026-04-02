import SwiftUI

struct NexusModCardView: View {
    let mod: NexusModInfo
    var isInstalled: Bool = false
    var isLikelyModpack: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                if let urlString = mod.pictureUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.parchmentHeader)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundStyle(Color.textMuted)
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack {
                    HStack {
                        if isLikelyModpack {
                            Text(L.s("nexus_modpack"))
                                .font(.stardew(size: 12))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.stardewPurple.opacity(0.15))
                                .foregroundStyle(Color.stardewPurple)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if isInstalled {
                            Text(L.s("nexus_installed"))
                                .font(.stardew(size: 12))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.stardewGreen.opacity(0.15))
                                .foregroundStyle(Color.stardewGreen)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(6)
            }

            // Info
            Text(mod.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textDark)
                .lineLimit(2)

            Text(mod.summary ?? "")
                .font(.system(size: 11))
                .foregroundStyle(Color.textLight)
                .lineLimit(3)

            HStack {
                Label(mod.author ?? "Unknown", systemImage: "person")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)

                Spacer()

                if let downloads = mod.modDownloads {
                    Label(formatNumber(downloads), systemImage: "arrow.down.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }

                if let endorsements = mod.endorsementCount {
                    Label(formatNumber(endorsements), systemImage: "hand.thumbsup")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.parchmentAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
        )
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
