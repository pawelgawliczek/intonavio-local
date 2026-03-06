import Foundation
import SwiftData

@Model
final class SessionModel {
    @Attribute(.unique) var id: String
    var duration: Int
    var loopStart: Double?
    var loopEnd: Double?
    var speed: Double
    var overallScore: Double
    var pitchLog: Data?
    var createdAt: Date

    var song: SongModel?

    init(
        id: String = UUID().uuidString,
        duration: Int,
        loopStart: Double? = nil,
        loopEnd: Double? = nil,
        speed: Double = 1.0,
        overallScore: Double = 0,
        pitchLog: [PitchLogEntry] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.duration = duration
        self.loopStart = loopStart
        self.loopEnd = loopEnd
        self.speed = speed
        self.overallScore = overallScore
        self.pitchLog = try? JSONEncoder().encode(pitchLog)
        self.createdAt = createdAt
    }

    var decodedPitchLog: [PitchLogEntry] {
        guard let data = pitchLog else { return [] }
        return (try? JSONDecoder().decode([PitchLogEntry].self, from: data)) ?? []
    }
}
