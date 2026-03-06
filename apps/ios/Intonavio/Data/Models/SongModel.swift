import Foundation
import SwiftData

@Model
final class SongModel {
    @Attribute(.unique) var id: String
    @Attribute(.unique) var videoId: String
    var title: String
    var artist: String?
    var thumbnailUrl: String
    var duration: Int
    var statusRaw: String
    var externalJobId: String?
    var errorMessage: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StemModel.song)
    var stems: [StemModel] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionModel.song)
    var sessions: [SessionModel] = []

    var status: SongStatus {
        get { SongStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    var hasPitchData: Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs
            .appendingPathComponent("pitch", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("reference.json")
        return FileManager.default.fileExists(atPath: path.path)
    }

    init(
        id: String = UUID().uuidString,
        videoId: String,
        title: String,
        artist: String? = nil,
        thumbnailUrl: String,
        duration: Int = 0,
        status: SongStatus = .queued,
        createdAt: Date = .now
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
    }
}
