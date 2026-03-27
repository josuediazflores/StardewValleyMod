import SwiftUI

struct ModpackImportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var acceptedRisks = false

    private var detectedType: ExternalDownloadService.URLType {
        ExternalDownloadService.detectURLType(urlString)
    }

    private var isNexusCollection: Bool {
        detectedType == .nexusCollection
    }

    private var needsTrustWarning: Bool {
        guard !urlString.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch detectedType {
        case .nexusCollection:
            return false
        case .googleDrive, .directZIP, .unknown:
            return true
        }
    }

    private var canImport: Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if needsTrustWarning && !acceptedRisks { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Import Modpack")
                .font(.stardew(size: 24))
                .foregroundStyle(Color.textDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.parchmentHeader)

            Divider()
                .overlay(Color.stardewDivider)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // URL input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL")
                            .font(.stardew(size: 16))
                            .foregroundStyle(Color.textDark)
                        TextField("https://...", text: $urlString)
                            .font(.stardew(size: 16))
                            .textFieldStyle(.roundedBorder)
                    }

                    // Detected source badge
                    if !urlString.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 8) {
                            Text("Detected:")
                                .font(.stardew(size: 14))
                                .foregroundStyle(Color.textLight)

                            detectedBadge
                        }
                    }

                    // Trust warning for non-Nexus URLs
                    if needsTrustWarning {
                        trustWarningView
                    }

                    // Loading
                    if appState.isModpackLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Downloading...")
                                .font(.stardew(size: 16))
                                .foregroundStyle(Color.textLight)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }

                    // Error
                    if let error = appState.modpackError {
                        Text(error)
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.stardewRed)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.stardewRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(20)
            }

            Spacer(minLength: 0)

            // Buttons
            Divider()
                .overlay(Color.stardewDivider)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.stardew(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.toggleOff.opacity(0.3))
                        .foregroundStyle(Color.textDark)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    performImport()
                } label: {
                    Text("Import")
                        .font(.stardew(size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(canImport ? Color.stardewGreen : Color.stardewGreen.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(!canImport || appState.isModpackLoading)
            }
            .padding(16)
        }
        .frame(width: 480, height: 440)
        .background(Color.parchment)
    }

    // MARK: - Detected Badge

    @ViewBuilder
    private var detectedBadge: some View {
        switch detectedType {
        case .nexusCollection:
            Text("Nexus Collection")
                .font(.stardew(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.stardewOrange.opacity(0.2))
                .foregroundStyle(Color.stardewOrange)
                .clipShape(Capsule())
        case .googleDrive:
            Text("Google Drive")
                .font(.stardew(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.stardewBlue.opacity(0.2))
                .foregroundStyle(Color.stardewBlue)
                .clipShape(Capsule())
        case .directZIP:
            Text("Direct Archive")
                .font(.stardew(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.stardewPurple.opacity(0.2))
                .foregroundStyle(Color.stardewPurple)
                .clipShape(Capsule())
        case .unknown:
            Text("Unknown Source")
                .font(.stardew(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.textMuted.opacity(0.2))
                .foregroundStyle(Color.textMuted)
                .clipShape(Capsule())
        }
    }

    // MARK: - Trust Warning

    @ViewBuilder
    private var trustWarningView: some View {
        let warning = TrustWarning.forURL(urlString)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.stardewOrange)
                    .font(.system(size: 16))
                Text("Security Warning")
                    .font(.stardew(size: 16))
                    .foregroundStyle(Color.stardewOrange)
            }

            Text(warning.message)
                .font(.stardew(size: 14))
                .foregroundStyle(Color.textDark)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(warning.risks, id: \.self) { risk in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                            .font(.stardew(size: 14))
                            .foregroundStyle(Color.stardewRed)
                        Text(risk)
                            .font(.stardew(size: 13))
                            .foregroundStyle(Color.textMedium)
                    }
                }
            }

            Toggle(isOn: $acceptedRisks) {
                Text("I understand the risks")
                    .font(.stardew(size: 14))
                    .foregroundStyle(Color.textDark)
            }
            .toggleStyle(StardewToggleStyle())
        }
        .padding(12)
        .background(Color.stardewOrange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.stardewOrange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Import Action

    private func performImport() {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if isNexusCollection {
            // Extract slug from Nexus collection URL
            let slug = extractNexusSlug(from: trimmed)
            Task {
                await appState.importNexusCollection(slug: slug)
                if appState.modpackError == nil {
                    dismiss()
                }
            }
        } else {
            Task {
                await appState.importModpackFromURL(urlString: trimmed)
                if appState.modpackError == nil {
                    dismiss()
                }
            }
        }
    }

    private func extractNexusSlug(from urlString: String) -> String {
        // Try to extract collection slug from URL like:
        // https://next.nexusmods.com/stardewvalley/collections/abcdef
        guard let url = URL(string: urlString) else { return urlString }
        let components = url.pathComponents
        if let collectionIndex = components.firstIndex(of: "collections"),
           collectionIndex + 1 < components.count {
            return components[collectionIndex + 1]
        }
        return url.lastPathComponent
    }
}
