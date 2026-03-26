import SwiftUI

struct NexusModCardView: View {
    let mod: NexusModInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let urlString = mod.pictureUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.fill.tertiary)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Info
            Text(mod.name)
                .font(.headline)
                .lineLimit(2)

            Text(mod.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Label(mod.author, systemImage: "person")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let downloads = mod.modDownloads {
                    Label(formatNumber(downloads), systemImage: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let endorsements = mod.endorsementCount {
                    Label(formatNumber(endorsements), systemImage: "hand.thumbsup")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
