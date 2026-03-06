import Foundation
import SwiftData

enum SongProcessingError: LocalizedError {
    case duplicateSong
    case invalidVideoId
    case cancelled

    var errorDescription: String? {
        switch self {
        case .duplicateSong: return "This song is already in your library"
        case .invalidVideoId: return "Could not extract video ID from the URL"
        case .cancelled: return "Processing was cancelled"
        }
    }
}

@Observable
final class SongProcessingService {
    private var processingTasks: [String: Task<Void, Never>] = [:]

    func processSong(
        youtubeUrl: String,
        videoId: String,
        modelContext: ModelContext
    ) async throws -> SongModel {
        // Check for duplicate
        let existingDescriptor = FetchDescriptor<SongModel>(
            predicate: #Predicate { $0.videoId == videoId }
        )
        let existing = try modelContext.fetch(existingDescriptor)
        if let song = existing.first {
            if song.status == .failed {
                song.status = .queued
                song.errorMessage = nil
                try modelContext.save()
                startProcessing(song: song, youtubeUrl: youtubeUrl, modelContext: modelContext)
                return song
            }
            throw SongProcessingError.duplicateSong
        }

        // Fetch metadata
        let metadata = try await YouTubeMetadataService.fetchMetadata(videoId: videoId)

        let song = SongModel(
            videoId: videoId,
            title: metadata.title,
            artist: metadata.author,
            thumbnailUrl: metadata.thumbnailUrl
        )
        modelContext.insert(song)
        try modelContext.save()

        startProcessing(song: song, youtubeUrl: youtubeUrl, modelContext: modelContext)
        return song
    }

    func cancelProcessing(songId: String) {
        processingTasks[songId]?.cancel()
        processingTasks.removeValue(forKey: songId)
    }

    func retryFailed(song: SongModel, modelContext: ModelContext) {
        let videoId = song.videoId
        let youtubeUrl = "https://www.youtube.com/watch?v=\(videoId)"
        song.status = .queued
        song.errorMessage = nil
        try? modelContext.save()
        startProcessing(song: song, youtubeUrl: youtubeUrl, modelContext: modelContext)
    }

    var isProcessing: Bool {
        !processingTasks.isEmpty
    }
}

// MARK: - Private

private extension SongProcessingService {
    func startProcessing(song: SongModel, youtubeUrl: String, modelContext: ModelContext) {
        let songId = song.id

        processingTasks[songId] = Task { @MainActor [weak self] in
            do {
                try await self?.runPipeline(
                    song: song,
                    youtubeUrl: youtubeUrl,
                    modelContext: modelContext
                )
            } catch {
                if !Task.isCancelled {
                    song.status = .failed
                    song.errorMessage = error.localizedDescription
                    try? modelContext.save()
                    AppLogger.library.error("Song processing failed: \(error.localizedDescription)")
                }
            }

            self?.processingTasks.removeValue(forKey: songId)
        }
    }

    @MainActor
    func runPipeline(song: SongModel, youtubeUrl: String, modelContext: ModelContext) async throws {
        try Task.checkCancellation()

        // Step 1: Create StemSplit job
        song.status = .splitting
        try modelContext.save()

        let jobId = try await StemSplitService.createJob(youtubeUrl: youtubeUrl)
        song.externalJobId = jobId
        try modelContext.save()

        // Step 2: Poll for completion
        let pollInterval: UInt64 = 15_000_000_000 // 15 seconds
        let maxAttempts = 40 // 10 minutes
        var jobResult: StemSplitJobResult?

        for _ in 0..<maxAttempts {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: pollInterval)

            let status = try await StemSplitService.getJobStatus(jobId: jobId)
            AppLogger.library.info("StemSplit job \(jobId) status: \(status.status)")

            if status.status == "COMPLETED" {
                jobResult = status
                if let duration = status.videoDuration ?? status.durationSeconds {
                    song.duration = duration
                }
                break
            }

            if status.status == "FAILED" {
                throw StemSplitError.jobFailed(message: status.error ?? "Unknown error")
            }
        }

        guard let result = jobResult, let outputs = result.outputs else {
            throw StemSplitError.timeout
        }

        try Task.checkCancellation()

        // Step 3: Download stems
        song.status = .downloading
        try modelContext.save()

        let stemDir = LocalStorageService.stemDirectory(songId: song.id)
        try LocalStorageService.ensureDirectory(at: stemDir)

        try await withThrowingTaskGroup(of: (String, Data).self) { group in
            for (stemName, output) in outputs {
                guard let downloadUrl = URL(string: output.url) else { continue }
                group.addTask {
                    let data = try await StemSplitService.downloadStem(from: downloadUrl)
                    return (stemName, data)
                }
            }

            for try await (stemName, data) in group {
                try Task.checkCancellation()

                guard let stemType = parseStemType(stemName) else { continue }
                let fileName = "\(stemType.rawValue.lowercased()).mp3"
                let fileURL = stemDir.appendingPathComponent(fileName)
                try data.write(to: fileURL)

                let stem = StemModel(
                    type: stemType,
                    localPath: "stems/\(song.id)/\(fileName)",
                    fileSize: data.count
                )
                stem.song = song
                modelContext.insert(stem)
            }
        }

        try modelContext.save()
        let stemCount = song.stems.count
        AppLogger.library.info("Downloaded \(stemCount) stems for song \(song.id)")

        try Task.checkCancellation()

        // Step 4: Run pitch analysis on vocal stem
        song.status = .analyzing
        try modelContext.save()

        let vocalStem = song.stems.first { $0.type == .vocals }
        if let vocalStem {
            let vocalURL = LocalStorageService.stemDirectory(songId: song.id)
                .appendingPathComponent(vocalStem.localPath.components(separatedBy: "/").last ?? "vocals.mp3")

            let pitchData = try await PitchAnalyzer.analyze(vocalStemURL: vocalURL)
            let pitchURL = LocalStorageService.pitchDataURL(songId: song.id)
            try LocalStorageService.ensureDirectory(at: pitchURL)
            let encoded = try JSONEncoder().encode(pitchData)
            try encoded.write(to: pitchURL)

            AppLogger.pitch.info("Pitch data saved for song \(song.id): \(pitchData.frameCount) frames")
        }

        // Step 5: Mark as ready
        song.status = .ready
        try modelContext.save()
        AppLogger.library.info("Song \(song.id) processing complete")
    }

    func parseStemType(_ name: String) -> StemType? {
        let normalized = name.uppercased()
        if normalized.contains("VOCAL") { return .vocals }
        if normalized.contains("DRUM") { return .drums }
        if normalized.contains("BASS") { return .bass }
        if normalized.contains("PIANO") { return .piano }
        if normalized.contains("GUITAR") { return .guitar }
        if normalized.contains("INSTRUMENT") { return .instrumental }
        if normalized.contains("OTHER") { return .other }
        return nil
    }
}
