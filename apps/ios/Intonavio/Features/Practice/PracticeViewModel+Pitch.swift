import Foundation

// MARK: - Pitch Detection & Scoring Integration

extension PracticeViewModel {
    /// Start pitch detection and scoring when playback begins.
    func startPitchDetection() {
        guard isPitchReady else { return }

        if pitchDetector == nil {
            pitchDetector = PitchDetector(engine: audioEngine)
        }

        guard let detector = pitchDetector else { return }

        do {
            try detector.start()
            detector.onPitchDetected = { [weak self] result in
                self?.handleDetectedPitch(result)
            }
        } catch {
            AppLogger.pitch.error(
                "Failed to start pitch detection: \(error.localizedDescription)"
            )
        }
    }

    /// Stop pitch detection.
    func stopPitchDetection() {
        pitchDetector?.stop()
        pitchDetector?.onPitchDetected = nil
    }

    /// Load reference pitch data from local Documents storage.
    func loadPitchDataIfAvailable() {
        let url = LocalStorageService.pitchDataURL(songId: songId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            isPitchReady = false
            return
        }

        do {
            try referenceStore.load(from: url)
            isPitchReady = true
            layoutMode = .pitchFocused
            AppLogger.pitch.info("Reference pitch loaded for practice")
        } catch {
            isPitchReady = false
            AppLogger.pitch.error(
                "Failed to load pitch data: \(error.localizedDescription)"
            )
        }
    }

    /// Set the transpose offset for reference pitch (visual + scoring).
    func setTranspose(_ semitones: Int) {
        transposeSemitones = semitones
        scoringEngine?.transposeSemitones = semitones
    }

    /// Handle each detected pitch result.
    func handleDetectedPitch(_ result: PitchResult) {
        guard !isWaitingForLoopSeek else { return }

        let midi = NoteMapper.frequencyToMidi(result.frequency)
        let now = result.timestamp

        // MIDI jump filter — reject points that jump >12 semitones within 50ms
        if lastDetectionTimestamp > 0 {
            let timeDelta = now - lastDetectionTimestamp
            let midiDelta = abs(midi - lastDetectedMidi)
            if timeDelta < PitchConstants.jumpTimeWindow,
               midiDelta > PitchConstants.maxMidiJump {
                return
            }
        }

        lastDetectedMidi = midi
        lastDetectionTimestamp = now

        scoringEngine?.evaluate(detected: result, playbackTime: currentTime)

        let rawRefHz = referenceStore.frame(at: currentTime)?.frequency
            ?? Double(result.frequency)
        let adjustedRefHz = rawRefHz * pow(2.0, Double(transposeSemitones) / 12.0)
        let cents = NoteMapper.centsBetween(
            detected: result.frequency,
            reference: Float(adjustedRefHz)
        )
        let accuracy = PitchAccuracy.classify(cents: cents)

        let point = DetectedPitchPoint(
            time: currentTime,
            midi: midi,
            accuracy: accuracy,
            cents: cents
        )
        detectedPoints.append(point)

        // Keep buffer at reasonable size (last 30 seconds at ~172/sec = 5160 points)
        if detectedPoints.count > 6000 {
            detectedPoints.removeFirst(1000)
        }
    }
}
