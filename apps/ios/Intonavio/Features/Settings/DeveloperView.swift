#if DEBUG
import SwiftData
import SwiftUI

/// Debug-only developer tools for local-only workflow.
struct DeveloperView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var songs: [SongModel] = []
    @State private var sessionCount = 0
    @State private var statusMessage: String?

    @State private var isPitchDebugEnabled = false
    @State private var isPitchRecording = false

    var body: some View {
        List {
            storageSection
            pitchDebugSection
            dataSection
        }
        .navigationTitle("Developer")
        .onAppear { loadData() }
    }
}

// MARK: - Sections

private extension DeveloperView {
    var storageSection: some View {
        Section("Local Data") {
            LabeledContent("Songs") {
                Text("\(songs.count)")
            }
            LabeledContent("Sessions") {
                Text("\(sessionCount)")
            }
            LabeledContent("Storage") {
                let bytes = LocalStorageService.totalStorageUsed()
                let formatter = ByteCountFormatter()
                Text(formatter.string(fromByteCount: bytes))
            }
            LabeledContent("API Key") {
                Image(systemName: KeychainService.hasStemSplitAPIKey ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(KeychainService.hasStemSplitAPIKey ? .green : .red)
            }
            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(songs, id: \.id) { song in
                DevSongRow(song: song)
            }
        }
    }

    var pitchDebugSection: some View {
        Section("Pitch Debug") {
            Toggle("Debug Overlay", isOn: $isPitchDebugEnabled)
            Toggle("Record Pitch Data", isOn: $isPitchRecording)
        }
    }

    var dataSection: some View {
        Section("Actions") {
            Button("Reload Data") { loadData() }
            Button("Clear API Key") {
                KeychainService.deleteStemSplitAPIKey()
                statusMessage = "API key removed"
            }
            .foregroundStyle(.red)
        }
    }
}

// MARK: - Data Loading

private extension DeveloperView {
    func loadData() {
        let songDescriptor = FetchDescriptor<SongModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        songs = (try? modelContext.fetch(songDescriptor)) ?? []

        let sessionDescriptor = FetchDescriptor<SessionModel>()
        sessionCount = (try? modelContext.fetchCount(sessionDescriptor)) ?? 0

        statusMessage = "Loaded \(songs.count) songs, \(sessionCount) sessions"
    }
}

/// Extracted row view for developer song list.
struct DevSongRow: View {
    let song: SongModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title).font(.body).lineLimit(2)
            HStack(spacing: 8) {
                statusBadge
                Text(song.videoId).font(.caption2).foregroundStyle(.tertiary)
            }
            if !song.stems.isEmpty {
                let types = song.stems.map(\.typeRaw).joined(separator: ", ")
                Text("\(song.stems.count) stems: \(types)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let error = song.errorMessage {
                Text(error)
                    .font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(song.status.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch song.status {
        case .ready: return .green
        case .failed: return .red
        case .queued, .downloading, .splitting, .analyzing: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperView()
    }
    .environment(AppState())
}
#endif
