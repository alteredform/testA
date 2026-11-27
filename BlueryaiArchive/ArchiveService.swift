import Foundation

struct ArchiveService {
    private let resolver = URL(string: "https://media.blueryai.xyz/api/connect/resolve.mjs")!

    func loadItems() async throws -> [ArchiveItem] {
        let rawURL = URL(string: resolver.absoluteString + "?raw")!
        if let rawData = try? await request(rawURL),
           let items = try? JSONDecoder().decode([ArchiveItem].self, from: rawData) {
            return items
        }

        let metadataData = try await request(resolver)
        let metadata = try JSONDecoder().decode(ResolverResponse.self, from: metadataData)
        guard let contentURL = metadata.url else {
            throw ArchiveError.invalidResponse
        }

        let contentData = try await request(contentURL)
        return try JSONDecoder().decode([ArchiveItem].self, from: contentData)
    }

    private func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ArchiveError.serverUnavailable
        }
        return data
    }
}

private struct ResolverResponse: Decodable {
    let url: URL?
}

enum ArchiveError: LocalizedError {
    case serverUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return "The archive could not be reached. Check your connection and try again."
        case .invalidResponse:
            return "The archive returned an unexpected response. Please try again later."
        }
    }
}
