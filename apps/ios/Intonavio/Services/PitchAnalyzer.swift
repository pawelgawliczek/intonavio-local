import Accelerate
import AVFoundation
import Foundation

enum PitchAnalyzerError: LocalizedError {
    case fileLoadFailed
    case noVocalContent

    var errorDescription: String? {
        switch self {
        case .fileLoadFailed:
            return "Failed to load vocal stem audio file"
        case .noVocalContent:
            return "No vocal content detected in the stem"
        }
    }
}

enum PitchAnalyzer {
    private static let sampleRate: Int = 44100
    private static let hopLength: Int = 512
    private static let windowSize: Int = 2048
    private static let rmsThreshold: Double = 0.02
    private static let minGapSeconds: Double = 0.3
    private static let minPhraseSeconds: Double = 0.5

    static func analyze(vocalStemURL: URL) async throws -> ReferencePitchData {
        let samples = try loadAudio(from: vocalStemURL)
        let frames = extractPitchFrames(from: samples)
        let hopDuration = Double(hopLength) / Double(sampleRate)
        let phrases = detectPhrases(frames: frames, hopDuration: hopDuration)

        let voicedCount = frames.filter(\.isVoiced).count
        let voicedPercent = frames.isEmpty ? 0 : Double(voicedCount) / Double(frames.count) * 100
        if voicedPercent < 5.0 {
            AppLogger.pitch.warning("Low voiced frame percentage: \(voicedPercent)%")
        }

        AppLogger.pitch.info(
            "Pitch analysis complete: \(frames.count) frames, \(voicedCount) voiced, \(phrases.count) phrases"
        )

        return ReferencePitchData(
            songId: nil,
            sampleRate: sampleRate,
            hopSize: hopLength,
            frameCount: frames.count,
            hopDuration: hopDuration,
            frames: frames,
            phrases: phrases
        )
    }
}

// MARK: - Audio Loading

private extension PitchAnalyzer {
    static func loadAudio(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(
            Double(file.length) * Double(sampleRate) / file.fileFormat.sampleRate
        )
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else {
            throw PitchAnalyzerError.fileLoadFailed
        }

        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            throw PitchAnalyzerError.fileLoadFailed
        }

        var isDone = false
        try converter.convert(to: buffer, error: nil) { _, outStatus in
            if isDone {
                outStatus.pointee = .noDataNow
                return nil
            }
            let readBuffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: 4096
            )!
            do {
                try file.read(into: readBuffer)
                if readBuffer.frameLength == 0 {
                    isDone = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return readBuffer
            } catch {
                isDone = true
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        guard let floatData = buffer.floatChannelData?[0] else {
            throw PitchAnalyzerError.fileLoadFailed
        }

        return Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
    }
}

// MARK: - Pitch Extraction

private extension PitchAnalyzer {
    static func extractPitchFrames(from samples: [Float]) -> [ReferencePitchFrame] {
        let detector = YINDetector(
            sampleRate: Float(sampleRate),
            threshold: PitchConstants.yinThreshold,
            minLag: Int(Float(sampleRate) / PitchConstants.maxFrequency),
            maxLag: Int(Float(sampleRate) / PitchConstants.minFrequency)
        )

        let totalFrames = max(0, (samples.count - windowSize) / hopLength + 1)
        var frames: [ReferencePitchFrame] = []
        frames.reserveCapacity(totalFrames)

        let hopDuration = Double(hopLength) / Double(sampleRate)

        for frameIndex in 0..<totalFrames {
            let start = frameIndex * hopLength
            let end = start + windowSize
            guard end <= samples.count else { break }

            let time = round(Double(frameIndex) * hopDuration * 10000) / 10000

            // Compute RMS
            var rmsValue: Float = 0
            samples.withUnsafeBufferPointer { bufferPtr in
                vDSP_rmsqv(bufferPtr.baseAddress! + start, 1, &rmsValue, vDSP_Length(windowSize))
            }

            // Run YIN detection
            let detection = samples.withUnsafeBufferPointer { bufferPtr -> (Float, Float)? in
                detector.detect(bufferPtr.baseAddress! + start, count: windowSize)
            }

            let isVoiced = detection != nil && rmsValue >= Float(rmsThreshold)

            if isVoiced, let (hz, _) = detection {
                let midi = 69.0 + 12.0 * log2(Double(hz) / 440.0)
                frames.append(ReferencePitchFrame(
                    time: time,
                    frequency: Double(hz),
                    isVoiced: true,
                    midiNote: round(midi * 10) / 10,
                    rms: Double(rmsValue)
                ))
            } else {
                frames.append(ReferencePitchFrame(
                    time: time,
                    frequency: nil,
                    isVoiced: false,
                    midiNote: nil,
                    rms: Double(rmsValue)
                ))
            }
        }

        return frames
    }
}

// MARK: - Phrase Detection (port of workers/pitch-analyzer/src/phrases.py)

private extension PitchAnalyzer {
    static func detectPhrases(
        frames: [ReferencePitchFrame],
        hopDuration: Double
    ) -> [ReferencePhraseInfo] {
        let raw = findRawPhrases(frames: frames, hopDuration: hopDuration)
        let merged = mergeShortPhrases(raw, hopDuration: hopDuration)
        return reindex(merged, frames: frames, hopDuration: hopDuration)
    }

    static func isActive(_ frame: ReferencePitchFrame) -> Bool {
        guard frame.isVoiced else { return false }
        if let rms = frame.rms, rms < rmsThreshold { return false }
        return true
    }

    static func findRawPhrases(
        frames: [ReferencePitchFrame],
        hopDuration: Double
    ) -> [(start: Int, end: Int)] {
        let minGapFrames = hopDuration > 0 ? Int(minGapSeconds / hopDuration) : 0
        var phrases: [(start: Int, end: Int)] = []
        var phraseStart: Int?
        var gapCount = 0

        for (i, frame) in frames.enumerated() {
            if isActive(frame) {
                if phraseStart == nil {
                    phraseStart = i
                }
                gapCount = 0
            } else {
                gapCount += 1
                if let start = phraseStart, gapCount > minGapFrames {
                    phrases.append((start: start, end: i - gapCount))
                    phraseStart = nil
                    gapCount = 0
                }
            }
        }

        if let start = phraseStart {
            var lastActive = start
            for i in stride(from: frames.count - 1, through: start, by: -1) {
                if isActive(frames[i]) {
                    lastActive = i
                    break
                }
            }
            phrases.append((start: start, end: lastActive))
        }

        return phrases
    }

    static func mergeShortPhrases(
        _ phrases: [(start: Int, end: Int)],
        hopDuration: Double
    ) -> [(start: Int, end: Int)] {
        guard phrases.count > 1 else { return phrases }

        let minFrames = hopDuration > 0 ? Int(minPhraseSeconds / hopDuration) : 0
        var result = phrases
        var changed = true

        while changed {
            changed = false
            var i = 0
            while i < result.count {
                let (start, end) = result[i]
                let voicedCount = end - start + 1
                guard voicedCount < minFrames else {
                    i += 1
                    continue
                }

                let mergeIdx: Int
                if i == 0, result.count > 1 {
                    mergeIdx = 1
                } else if i == result.count - 1, result.count > 1 {
                    mergeIdx = i - 1
                } else if result.count > 1 {
                    let gapBefore = start - result[i - 1].end
                    let gapAfter = result[i + 1].start - end
                    mergeIdx = gapBefore <= gapAfter ? i - 1 : i + 1
                } else {
                    i += 1
                    continue
                }

                let lo = min(i, mergeIdx)
                let hi = max(i, mergeIdx)
                let merged = (start: result[lo].start, end: result[hi].end)
                result[lo] = merged
                result.remove(at: hi)
                changed = true
                break
            }
        }

        return result
    }

    static func reindex(
        _ raw: [(start: Int, end: Int)],
        frames: [ReferencePitchFrame],
        hopDuration: Double
    ) -> [ReferencePhraseInfo] {
        raw.enumerated().map { idx, pair in
            let voiced = (pair.start...pair.end).reduce(0) { count, i in
                count + (frames[i].isVoiced ? 1 : 0)
            }
            return ReferencePhraseInfo(
                index: idx,
                startFrame: pair.start,
                endFrame: pair.end,
                startTime: round(Double(pair.start) * hopDuration * 1_000_000) / 1_000_000,
                endTime: round(Double(pair.end) * hopDuration * 1_000_000) / 1_000_000,
                voicedFrameCount: voiced
            )
        }
    }
}
