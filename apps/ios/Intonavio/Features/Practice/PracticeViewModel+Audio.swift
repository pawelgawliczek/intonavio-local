import Foundation
import SwiftData

// MARK: - Audio Mode & Stem Management

extension PracticeViewModel {
    /// Switch audio source: original (FULL stem or YouTube), vocals only, or instrumental.
    /// Uses pause-switch-resume to prevent sync issues during transition.
    @MainActor
    func setAudioMode(_ mode: AudioMode) {
        guard mode != audioMode else { return }

        guard isStemsReady else {
            loadLocalStemsAndSwitch(to: mode)
            return
        }

        let wasPlaying = loopState == .playing || loopState == .looping
        let resumeTime = currentTime

        if wasPlaying {
            sync?.stop()
            stemPlayer.stop()
        }

        // Mute YouTube once stems are ready (for songs with FULL stem)
        if hasFullStem && !isMuted {
            controller.mute()
            isMuted = true
        }

        // Legacy fallback: songs without FULL stem use YouTube for original mode
        if !hasFullStem {
            if mode == .original {
                switchToOriginal()
                audioMode = mode
                return
            }
            if audioMode == .original && !isMuted {
                controller.mute()
                isMuted = true
            }
        }

        audioMode = mode
        stemPlayer.applyMode(mode)
        stemPlayer.rate = Float(playbackRate)

        if wasPlaying {
            stemPlayer.play(from: resumeTime)
            sync?.start()
        }
    }

    /// Load stems from local storage so mode switching is instant.
    func preloadStems() {
        guard !stems.isEmpty, !isStemsReady, !isDownloadingStems else { return }
        Task { @MainActor in
            await loadLocalStems()
        }
    }
}

// MARK: - Private

private extension PracticeViewModel {
    @MainActor
    func switchToOriginal() {
        sync?.stop()
        stemPlayer.stop()
        controller.unmute()
        isMuted = false
    }

    @MainActor
    func loadLocalStemsAndSwitch(to mode: AudioMode) {
        Task { @MainActor in
            await loadLocalStems()
            guard isStemsReady else { return }
            setAudioMode(mode)
        }
    }

    @MainActor
    func loadLocalStems() async {
        guard !isDownloadingStems else { return }
        isDownloadingStems = true

        do {
            var stemFiles: [(type: StemType, url: URL)] = []
            for stem in stems {
                let url = LocalStorageService.stemURL(songId: songId, type: stem.type)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    AppLogger.audio.warning("Stem file missing: \(url.lastPathComponent)")
                    continue
                }
                stemFiles.append((type: stem.type, url: url))
            }

            try stemPlayer.setup(stems: stemFiles)
            isStemsReady = true
            let count = stemFiles.count
            AppLogger.audio.info("Stems ready: \(count) loaded from local storage")

            // Auto-mute YouTube and activate FULL stem when available
            if hasFullStem {
                controller.mute()
                isMuted = true
                stemPlayer.applyMode(audioMode)
            }
        } catch {
            AppLogger.audio.error(
                "Stem loading failed: \(error.localizedDescription)"
            )
        }

        isDownloadingStems = false
    }
}

// MARK: - Session Auto-Save

extension PracticeViewModel {
    func saveSessionIfNeeded(modelContext: ModelContext? = nil) {
        guard !sessionSaved,
              playbackDuration >= Self.minimumPlaybackForSave else {
            return
        }
        sessionSaved = true

        let score = scoringEngine?.finalScore ?? 0
        let log = scoringEngine?.pitchLog ?? []

        guard let modelContext else {
            AppLogger.sessions.warning("No model context for session save")
            return
        }

        let session = SessionModel(
            duration: Int(playbackDuration),
            loopStart: markerA,
            loopEnd: markerB,
            speed: playbackRate,
            overallScore: score,
            pitchLog: log
        )

        // Link to song if possible
        let songIdValue = songId
        let descriptor = FetchDescriptor<SongModel>(
            predicate: #Predicate { $0.id == songIdValue }
        )
        if let song = try? modelContext.fetch(descriptor).first {
            session.song = song
        }

        modelContext.insert(session)
        try? modelContext.save()
        AppLogger.sessions.info("Auto-saved session for song \(songIdValue)")
    }
}
