import Foundation
import SwiftData

@Model
final class StemModel {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var localPath: String
    var format: String
    var fileSize: Int

    var song: SongModel?

    var type: StemType {
        get { StemType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        type: StemType,
        localPath: String,
        format: String = "mp3",
        fileSize: Int = 0
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.localPath = localPath
        self.format = format
        self.fileSize = fileSize
    }
}
