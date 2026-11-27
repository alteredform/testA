import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid API URL."
        case .badResponse(let code): return "Server returned HTTP \(code)."
        case .emptyData:             return "No data received."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 30
        session = URLSession(configuration: cfg)
    }

    func fetchItems(type: ItemType? = nil) async throws -> [ArchiveItem] {
        let url = APIConfig.itemsURL(type: type)
        let (data, resp) = try await session.data(from: url)

        guard let http = resp as? HTTPURLResponse else { throw APIError.emptyData }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(http.statusCode)
        }
        guard !data.isEmpty else { throw APIError.emptyData }

        // resolve.mjs?raw should return a bare array, but be tolerant.
        if let arr = try? decoder.decode([ArchiveItem].self, from: data) {
            return arr
        }
        if
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let arr = obj["items"] as? [[String: Any]] ?? obj["data"] as? [[String: Any]]
        {
            let wrapped = try JSONSerialization.data(withJSONObject: arr)
            return try decoder.decode([ArchiveItem].self, from: wrapped)
        }
        throw APIError.emptyData
    }
}