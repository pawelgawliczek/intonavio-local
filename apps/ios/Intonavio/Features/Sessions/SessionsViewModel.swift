import Foundation
import SwiftData

/// Manages session history using local SwiftData storage.
@Observable
final class SessionsViewModel {
    var sessions: [SessionModel] = []
    var isLoading = false
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Fetch

    func fetchSessions() {
        guard let modelContext else { return }
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<SessionModel>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            sessions = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.sessions.error("Failed to load sessions: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
