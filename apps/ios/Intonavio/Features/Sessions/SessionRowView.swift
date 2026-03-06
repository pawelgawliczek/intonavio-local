import SwiftUI

struct SessionRowView: View {
    let session: SessionModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.song?.title ?? "Unknown Song")
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.intonavioTextSecondary)
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundStyle(Color.intonavioTextSecondary)
                    if session.speed != 1.0 {
                        Text(String(format: "%.2gx", session.speed))
                            .font(.caption)
                            .foregroundStyle(Color.intonavioTextSecondary)
                    }
                }
            }
            Spacer()
            Text(String(format: "%.0f%%", session.overallScore))
                .font(.headline)
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

private extension SessionRowView {
    var formattedDate: String {
        session.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var formattedDuration: String {
        let mins = session.duration / 60
        let secs = session.duration % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var scoreColor: Color {
        switch session.overallScore {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}
