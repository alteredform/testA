import Foundation

/// A single playback source (YouTube, Mega, Archive.org, GoFile, direct MP4…).
struct Backup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let url: String
    let description: String?
    let unavailable: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id          = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name        = (try? c.decode(String.self, forKey: .name)) ?? "Source"
        self.url         = try c.decode(String.self, forKey: .url)
        self.description = try? c.decode(String.self, forKey: .description)
        self.unavailable = (try? c.decode(Bool.self, forKey: .unavailable)) ?? false
    }

    enum CodingKeys: String, CodingKey { case id, name, url, description, unavailable }

    // MARK: - Playback helpers

    var youTubeVideoId: String? {
        let patterns = [
            #"[?&]v=([\w-]{11})"#,
            #"youtu\.be/([\w-]{11})"#,
            #"/embed/([\w-]{11})"#,
        ]
        for p in patterns {
            if let r = url.range(of: p, options: .regularExpression) {
                return String(url[r].suffix(11))
            }
        }
        return nil
    }

    var isYouTube: Bool { youTubeVideoId != nil }

    var isDirectMedia: Bool {
        let l = url.lowercased()
        return [".mp4", ".m3u8", ".webm", ".mov", ".mkv",
                ".mp3", ".m4a", ".aac", ".flac", ".opus"]
            .contains { l.hasSuffix($0) || l.contains("\($0)?") }
    }

    /// URL to hand to the player (native or WKWebView).
    var playbackURL: URL? {
        if let yt = youTubeVideoId {
            return URL(string: "https://www.youtube.com/embed/\(yt)?rel=0&playsinline=1")
        }
        return URL(string: url)
    }
}