import Foundation

enum StemSplitError: LocalizedError {
    case noAPIKey
    case jobCreationFailed(statusCode: Int, body: String)
    case statusCheckFailed(statusCode: Int, body: String)
    case downloadFailed(statusCode: Int)
    case timeout
    case jobFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "StemSplit API key not configured. Add it in Settings."
        case .jobCreationFailed(let code, let body):
            return "StemSplit job creation failed (\(code)): \(body)"
        case .statusCheckFailed(let code, let body):
            return "StemSplit status check failed (\(code)): \(body)"
        case .downloadFailed(let code):
            return "Stem download failed with status \(code)"
        case .timeout:
            return "Stem separation timed out after 10 minutes"
        case .jobFailed(let message):
            return "Stem separation failed: \(message)"
        }
    }
}

struct StemSplitJobResult: Decodable, Sendable {
    let status: String
    let outputs: [String: StemOutput]?
    let videoDuration: Int?
    let durationSeconds: Int?
    let error: String?

    struct StemOutput: Decodable, Sendable {
        let url: String
        let expiresAt: String
    }
}

enum StemSplitService {
    private static let apiUrl = "https://api.stemsplit.com"
    private static let session = URLSession.shared

    static func createJob(youtubeUrl: String) async throws -> String {
        guard let apiKey = KeychainService.getStemSplitAPIKey() else {
            throw StemSplitError.noAPIKey
        }

        let body: [String: String] = [
            "youtubeUrl": youtubeUrl,
            "outputType": "SIX_STEMS",
            "outputFormat": "MP3",
            "quality": "BEST"
        ]

        var request = URLRequest(url: URL(string: "\(apiUrl)/api/v1/youtube-jobs")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StemSplitError.jobCreationFailed(
                statusCode: httpResponse.statusCode,
                body: errorBody
            )
        }

        struct CreateJobResponse: Decodable {
            let id: String
        }

        let result = try JSONDecoder().decode(CreateJobResponse.self, from: data)
        AppLogger.audio.info("StemSplit job created: \(result.id)")
        return result.id
    }

    static func getJobStatus(jobId: String) async throws -> StemSplitJobResult {
        guard let apiKey = KeychainService.getStemSplitAPIKey() else {
            throw StemSplitError.noAPIKey
        }

        var request = URLRequest(url: URL(string: "\(apiUrl)/api/v1/youtube-jobs/\(jobId)")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StemSplitError.statusCheckFailed(
                statusCode: httpResponse.statusCode,
                body: errorBody
            )
        }

        return try JSONDecoder().decode(StemSplitJobResult.self, from: data)
    }

    static func downloadStem(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw StemSplitError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        return data
    }
}
