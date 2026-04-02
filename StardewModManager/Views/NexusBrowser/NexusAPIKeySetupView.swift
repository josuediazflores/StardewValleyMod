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

            Text(L.s("nexus_connect_title"))
                .font(.title2.weight(.bold))

            Text(L.s("nexus_connect_desc"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                Text(L.s("nexus_api_key"))
                    .font(.headline)

                SecureField(L.s("nexus_api_placeholder"), text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)
            }

            HStack(spacing: 12) {
                Button(L.s("nexus_get_key")) {
                    if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Button(L.s("nexus_validate")) {
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
                ProgressView()
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
