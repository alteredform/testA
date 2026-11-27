import Foundation

enum APIConfig {
    static let mediaBase = URL(string: "https://media.blueryai.xyz")!
    static let siteBase  = URL(string: "https://blueryai.xyz")!

    // Vercel strips .js; .mjs keeps its extension.
    private static let itemsPath     = "/api/connect/resolve.mjs"
    private static let chatProxyPath = "/api/chat/chat"
    private static let reportPath    = "/api/report/report"
    static  let browsePath           = "/api/browse"

    /// Full item list. `?raw` returns JSON instead of whatever the mjs would otherwise emit.
    static func itemsURL(type: ItemType? = nil) -> URL {
        var c = URLComponents(
            url: mediaBase.appendingPathComponent(itemsPath),
            resolvingAgainstBaseURL: false
        )!
        var q: [URLQueryItem] = [URLQueryItem(name: "raw", value: nil)]
        if let type { q.append(URLQueryItem(name: "type", value: type.rawValue)) }
        c.queryItems = q
        return c.url!
    }

    /// Wrap a raw chat URL (gofile, etc.) so CORS + auth are handled by the proxy.
    static func chatProxyURL(for rawURL: String) -> URL? {
        guard !rawURL.isEmpty,
              let encoded = rawURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "\(mediaBase.absoluteString)\(chatProxyPath)?url=\(encoded)")
    }

    static var reportURL: URL { mediaBase.appendingPathComponent(reportPath) }

    /// Resolve a possibly-relative asset path against the site root.
    static func resolveAssetURL(_ path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return siteBase.appendingPathComponent(path)
    }

    /// Streamed URL for a file living in the GitHub repo (Range-capable for media).
    static func browseURL(for repoPath: String) -> URL {
        let clean = repoPath.hasPrefix("/") ? String(repoPath.dropFirst()) : repoPath
        return mediaBase
            .appendingPathComponent(String(browsePath.dropFirst()))
            .appendingPathComponent(clean)
    }
}