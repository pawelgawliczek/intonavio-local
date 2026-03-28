import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var isShowingScoreResetConfirmation = false
    @State private var scoresCleared = false
    @Environment(\.modelContext) private var modelContext
    @AppStorage("difficultyLevel") private var difficultyRaw = DifficultyLevel.beginner.rawValue

    var body: some View {
        List {
            apiKeySection
            audioInputSection
            guideToneSection
            difficultySection
            storageSection
            aboutSection
            #if DEBUG
            developerSection
            #endif
        }
        .navigationTitle("Settings")
        .onAppear { viewModel.loadAudioInputs() }
        .alert("Error", isPresented: hasError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Sections

private extension SettingsView {
    var apiKeySection: some View {
        Section("StemSplit API") {
            NavigationLink {
                APIKeySettingsView()
            } label: {
                HStack {
                    Text("API Key")
                    Spacer()
                    if KeychainService.hasStemSplitAPIKey {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not Set")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    var audioInputSection: some View {
        Section("Audio Input") {
            #if os(iOS)
            ForEach(viewModel.availableInputs, id: \.uid) { port in
                Button {
                    viewModel.selectInput(port)
                } label: {
                    HStack {
                        Text(port.portName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if port.uid == viewModel.selectedInputUID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if viewModel.availableInputs.isEmpty {
                Text("No audio inputs available")
                    .foregroundStyle(.secondary)
            }
            #else
            ForEach(viewModel.availableDevices, id: \.uniqueID) { device in
                Button {
                    viewModel.selectDevice(device)
                } label: {
                    HStack {
                        Text(device.localizedName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if device.uniqueID == viewModel.selectedInputUID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            if viewModel.availableDevices.isEmpty {
                Text("No audio inputs available")
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }

    var guideToneSection: some View {
        Section("Guide Tone") {
            NavigationLink {
                GuideToneSettingsView()
            } label: {
                HStack {
                    Text("Instrument")
                    Spacer()
                    Text(currentGuideToneLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var currentGuideToneLabel: String {
        let stored = UserDefaults.standard.integer(forKey: "guideToneInstrument")
        let instrument = GuideToneInstrument(rawValue: stored) ?? .acousticGrandPiano
        return instrument.label
    }

    var difficultySection: some View {
        Section {
            Picker("Difficulty", selection: $difficultyRaw) {
                ForEach(DifficultyLevel.allCases, id: \.rawValue) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if let selected = DifficultyLevel(rawValue: difficultyRaw) {
                HStack(spacing: 8) {
                    Image(systemName: selected.icon)
                        .foregroundStyle(.secondary)
                    Text(selected.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DifficultyZonePreview(difficulty: selected)
            }
        } header: {
            Text("Difficulty")
        } footer: {
            Text("Controls how precisely you need to match the pitch. Beginner has wider tolerance zones.")
        }
    }

    var storageSection: some View {
        Section {
            HStack {
                Text("Storage Used")
                Spacer()
                Text(formattedStorageSize)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }

            Button {
                isShowingScoreResetConfirmation = true
            } label: {
                HStack {
                    Text("Reset All Scores")
                    Spacer()
                    if scoresCleared {
                        Text("Cleared")
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
            .disabled(scoresCleared)
            .confirmationDialog(
                "Reset all scores?",
                isPresented: $isShowingScoreResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset All Scores", role: .destructive) {
                    ScoreRepository(modelContext: modelContext).deleteAllScoresGlobally()
                    scoresCleared = true
                }
            } message: {
                Text("This will delete all scores for all songs across all difficulties. This cannot be undone.")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Stems and pitch data are stored locally on your device. Reset All Scores clears your score history.")
        }
    }

    private var formattedStorageSize: String {
        let bytes = LocalStorageService.totalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(Color.intonavioTextSecondary)
            }
        }
    }

    #if DEBUG
    var developerSection: some View {
        Section("Developer") {
            NavigationLink {
                DeveloperView()
            } label: {
                Label("Developer Tools", systemImage: "hammer")
            }
        }
    }
    #endif
}

// MARK: - Helpers

private extension SettingsView {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Difficulty Zone Preview

private struct DifficultyZonePreview: View {
    let difficulty: DifficultyLevel

    private let maxCents = DifficultyLevel.beginner.fairCents

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: width * CGFloat(difficulty.fairCents / maxCents))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.4))
                    .frame(width: width * CGFloat(difficulty.goodCents / maxCents))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: width * CGFloat(difficulty.excellentCents / maxCents))
            }
        }
        .frame(height: 12)

        HStack {
            Label("Perfect", systemImage: "circle.fill")
                .foregroundStyle(.green)
            Spacer()
            Label("Good", systemImage: "circle.fill")
                .foregroundStyle(.yellow)
            Spacer()
            Label("OK", systemImage: "circle.fill")
                .foregroundStyle(.orange)
        }
        .font(.caption2)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
}
