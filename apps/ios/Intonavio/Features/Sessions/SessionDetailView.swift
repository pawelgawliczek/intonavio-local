import SwiftData
import SwiftUI

struct SessionDetailView: View {
    let sessionId: String

    @Environment(\.modelContext) private var modelContext
    @State private var session: SessionModel?

    var body: some View {
        Group {
            if let session {
                sessionContent(session)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSession() }
    }

    private func loadSession() {
        let id = sessionId
        let descriptor = FetchDescriptor<SessionModel>(
            predicate: #Predicate { $0.id == id }
        )
        session = try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Content

private extension SessionDetailView {
    func sessionContent(_ session: SessionModel) -> some View {
        List {
            Section("Score") {
                HStack {
                    Text("Overall")
                    Spacer()
                    Text(String(format: "%.1f%%", session.overallScore))
                        .font(.title2.bold())
                }
            }

            Section("Details") {
                detailRow("Duration", "\(session.duration)s")
                detailRow("Speed", String(format: "%.2gx", session.speed))
                if let start = session.loopStart, let end = session.loopEnd {
                    detailRow("Loop", "\(formatTime(start)) - \(formatTime(end))")
                }
                if let song = session.song {
                    detailRow("Song", song.title)
                }
            }

            Section("Pitch Graph") {
                let logCount = session.decodedPitchLog.count
                Text("\(logCount) pitch log entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: "sess1")
    }
}
