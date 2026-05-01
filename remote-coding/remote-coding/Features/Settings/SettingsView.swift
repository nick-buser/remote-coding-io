import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var apiBaseURL = ""
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("API base URL", text: $apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    LabeledContent("Current", value: appModel.apiConfiguration.baseURL.absoluteString)

                    if appModel.isUsingMockRepository {
                        Label("Using mock repository", systemImage: "shippingbox")
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let savedMessage {
                        Text(savedMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button("Save backend URL") {
                        save()
                    }

                    Button("Reset to local default") {
                        appModel.resetAPIBaseURL()
                        apiBaseURL = appModel.apiConfiguration.baseURL.absoluteString
                        errorMessage = nil
                        savedMessage = "Reset to local backend."
                    }
                }

                Section("Development") {
                    Text("Default local URL is \(APIConfiguration.default.baseURL.absoluteString). Use a LAN IP or hostname here when testing on a physical device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                apiBaseURL = appModel.apiConfiguration.baseURL.absoluteString
            }
        }
    }

    private func save() {
        do {
            try appModel.updateAPIBaseURL(apiBaseURL)
            apiBaseURL = appModel.apiConfiguration.baseURL.absoluteString
            errorMessage = nil
            savedMessage = "Backend URL saved."
        } catch {
            errorMessage = error.localizedDescription
            savedMessage = nil
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}

