import Foundation
import SwiftData

/// Manages the user's song library using local SwiftData storage.
@Observable
final class LibraryViewModel {
    var songs: [SongModel] = []
    var isLoading = false
    var isAddingSong = false
    var errorMessage: String?
    var showAddSheet = false
    var addSongURL = ""
    var addSongError: String?

    let processingService = SongProcessingService()
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Fetch Songs

    func fetchSongs() {
        guard let modelContext else { return }
        isLoading = true
        errorMessage = nil

        do {
            let descriptor = FetchDescriptor<SongModel>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            songs = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.library.error("Failed to load songs: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Add Song

    func addSong() {
        guard validateURL() else { return }
        Task { @MainActor in
            await performAddSong()
        }
    }

    // MARK: - Delete Song

    @MainActor
    func deleteSong(_ song: SongModel) {
        guard let modelContext else { return }
        processingService.cancelProcessing(songId: song.id)
        LocalStorageService.deleteSongFiles(songId: song.id)
        modelContext.delete(song)
        try? modelContext.save()
        songs.removeAll { $0.id == song.id }
    }

    // MARK: - Retry Failed

    @MainActor
    func retryFailed(_ song: SongModel) {
        guard let modelContext else { return }
        processingService.retryFailed(song: song, modelContext: modelContext)
    }
}

// MARK: - Private

private extension LibraryViewModel {
    @MainActor
    func performAddSong() async {
        guard let modelContext else { return }
        isAddingSong = true
        addSongError = nil

        guard KeychainService.hasStemSplitAPIKey else {
            addSongError = "Set your StemSplit API key in Settings first."
            isAddingSong = false
            return
        }

        let videoId = YouTubeURLValidator.extractVideoId(addSongURL)
        guard let videoId, !videoId.isEmpty else {
            addSongError = "Could not extract video ID from URL"
            isAddingSong = false
            return
        }

        do {
            let song = try await processingService.processSong(
                youtubeUrl: addSongURL,
                videoId: videoId,
                modelContext: modelContext
            )

            if !songs.contains(where: { $0.id == song.id }) {
                songs.insert(song, at: 0)
            }

            addSongURL = ""
            showAddSheet = false
            AppLogger.library.info("Song added: \(song.id)")
        } catch {
            addSongError = error.localizedDescription
            AppLogger.library.error("Failed to add song: \(error.localizedDescription)")
        }

        isAddingSong = false
    }

    func validateURL() -> Bool {
        guard !addSongURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            addSongError = "Please enter a YouTube URL"
            return false
        }
        guard YouTubeURLValidator.isValid(addSongURL) else {
            addSongError = "Invalid YouTube URL"
            return false
        }
        return true
    }
}
