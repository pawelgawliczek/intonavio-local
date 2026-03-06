import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty, !viewModel.isLoading {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Sessions")
        .onAppear {
            viewModel.setModelContext(modelContext)
            if viewModel.sessions.isEmpty {
                viewModel.fetchSessions()
            }
        }
    }
}

// MARK: - Subviews

private extension SessionHistoryView {
    var sessionList: some View {
        List {
            ForEach(viewModel.sessions, id: \.id) { session in
                SessionRowView(session: session)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(Color.intonavioTextSecondary)
            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Practice a song to see your history here")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
}
