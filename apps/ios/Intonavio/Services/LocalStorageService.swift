import Foundation

enum LocalStorageService {
    private static let fileManager = FileManager.default

    private static var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func stemDirectory(songId: String) -> URL {
        documentsDirectory
            .appendingPathComponent("stems", isDirectory: true)
            .appendingPathComponent(songId, isDirectory: true)
    }

    static func stemURL(songId: String, type: StemType) -> URL {
        stemDirectory(songId: songId)
            .appendingPathComponent("\(type.rawValue.lowercased()).mp3")
    }

    static func pitchDataURL(songId: String) -> URL {
        documentsDirectory
            .appendingPathComponent("pitch", isDirectory: true)
            .appendingPathComponent(songId, isDirectory: true)
            .appendingPathComponent("reference.json")
    }

    static func pitchDataExists(songId: String) -> Bool {
        fileManager.fileExists(atPath: pitchDataURL(songId: songId).path)
    }

    static func deleteSongFiles(songId: String) {
        let stemDir = stemDirectory(songId: songId)
        try? fileManager.removeItem(at: stemDir)

        let pitchDir = pitchDataURL(songId: songId).deletingLastPathComponent()
        try? fileManager.removeItem(at: pitchDir)
    }

    static func ensureDirectory(at url: URL) throws {
        let dir = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    static func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        let stemsDir = documentsDirectory.appendingPathComponent("stems", isDirectory: true)
        let pitchDir = documentsDirectory.appendingPathComponent("pitch", isDirectory: true)

        for dir in [stemsDir, pitchDir] {
            if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    total += Int64(size)
                }
            }
        }
        return total
    }
}
