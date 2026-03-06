import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey = ""
    @State private var isSaved = false
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?

    enum ValidationResult {
        case valid
        case invalid(String)
    }

    var body: some View {
        List {
            Section {
                SecureField("Paste your API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, _ in
                        isSaved = false
                        validationResult = nil
                    }
            } header: {
                Text("StemSplit API Key")
            } footer: {
                Text("Your API key is stored securely in the device Keychain and never leaves your device.")
            }

            Section {
                Button {
                    saveKey()
                } label: {
                    HStack {
                        Text("Save")
                        Spacer()
                        if isSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    Task { await validateKey() }
                } label: {
                    HStack {
                        Text("Validate Key")
                        Spacer()
                        if isValidating {
                            ProgressView()
                        } else if let result = validationResult {
                            switch result {
                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .invalid:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)

                if case .invalid(let message) = validationResult {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if KeychainService.hasStemSplitAPIKey {
                Section {
                    Button("Remove Saved Key", role: .destructive) {
                        KeychainService.deleteStemSplitAPIKey()
                        apiKey = ""
                        isSaved = false
                        validationResult = nil
                    }
                }
            }
        }
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let existing = KeychainService.getStemSplitAPIKey() {
                apiKey = existing
                isSaved = true
            }
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        KeychainService.setStemSplitAPIKey(trimmed)
        isSaved = true
    }

    private func validateKey() async {
        saveKey()
        isValidating = true
        defer { isValidating = false }

        do {
            // Try creating a dummy job status check - this will validate the auth
            _ = try await StemSplitService.getJobStatus(jobId: "test-validation")
            validationResult = .valid
        } catch let error as StemSplitError {
            switch error {
            case .statusCheckFailed(let code, _) where code == 401:
                validationResult = .invalid("Invalid API key")
            case .statusCheckFailed(let code, _) where code == 404:
                // 404 means auth worked but job not found - key is valid
                validationResult = .valid
            default:
                validationResult = .invalid(error.localizedDescription)
            }
        } catch {
            validationResult = .invalid(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        APIKeySettingsView()
    }
}
