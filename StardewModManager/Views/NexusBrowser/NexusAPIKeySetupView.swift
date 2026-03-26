import SwiftUI

struct NexusAPIKeySetupView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Connect to Nexus Mods")
                .font(.title2.weight(.bold))

            Text("Enter your Nexus Mods API key to browse and download mods directly.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.headline)

                SecureField("Paste your API key here...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
            }

            HStack(spacing: 12) {
                Button("Get API Key") {
                    if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Button("Validate & Save") {
                    isValidating = true
                    Task {
                        await appState.validateNexusAPIKey(apiKeyInput)
                        isValidating = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty || isValidating)
            }

            if isValidating {
                ProgressView("Validating...")
            }

            if let error = appState.nexusError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
