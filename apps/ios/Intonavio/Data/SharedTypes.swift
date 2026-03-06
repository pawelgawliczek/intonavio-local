import Foundation

// MARK: - Song Status

enum SongStatus: String, Codable, Sendable {
    case queued = "QUEUED"
    case downloading = "DOWNLOADING"
    case splitting = "SPLITTING"
    case analyzing = "ANALYZING"
    case ready = "READY"
    case failed = "FAILED"

    var isProcessing: Bool {
        switch self {
        case .queued, .downloading, .splitting, .analyzing: return true
        case .ready, .failed: return false
        }
    }
}

// MARK: - Stem Type

enum StemType: String, Codable, Sendable {
    case vocals = "VOCALS"
    case instrumental = "INSTRUMENTAL"
    case drums = "DRUMS"
    case bass = "BASS"
    case other = "OTHER"
    case piano = "PIANO"
    case guitar = "GUITAR"
    case full = "FULL"
}

// MARK: - Session DTOs

struct PitchLogEntry: Codable, Sendable {
    let time: Double
    let detectedHz: Double?
    let referenceHz: Double?
    let cents: Double?
}
