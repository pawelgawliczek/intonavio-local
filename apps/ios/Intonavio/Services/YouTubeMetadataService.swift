import Foundation

struct YouTubeMetadata: Sendable {
    let title: String
    let author: String?
    let thumbnailUrl: String
}

enum YouTubeMetadataService {
    private static let session = URLSession.shared

    static func fetchMetadata(videoId: String) async throws -> YouTubeMetadata {
        let youtubeUrl = "https://www.youtube.com/watch?v=\(videoId)"
        let oembedUrl = URL(string: "https://www.youtube.com/oembed?url=\(youtubeUrl)&format=json")!

        let (data, _) = try await session.data(from: oembedUrl)

        struct OEmbedResponse: Decodable {
            let title: String
            let author_name: String?
        }

        let oembed = try JSONDecoder().decode(OEmbedResponse.self, from: data)
        let thumbnailUrl = await bestThumbnail(videoId: videoId)

        return YouTubeMetadata(
            title: oembed.title,
            author: oembed.author_name,
            thumbnailUrl: thumbnailUrl
        )
    }

    private static func bestThumbnail(videoId: String) async -> String {
        let candidates = [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            if let (_, response) = try? await session.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return candidate
            }
        }

        return candidates.last!
    }
}
