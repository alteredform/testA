import Foundation

struct ArchiveItem: Codable, Identifiable, Hashable {
    let sourceID: String?
    let youtubeId: String?
    let title: String?
    let date: String?
    let duration: String?
    let description: String?
    let categories: [String]?
    let services: [String]?
    let service: String?
    let segment: [String]?
    let thumbnails: [String]?
    let backups: [ArchiveBackup]?
    let chat: ArchiveChat?
    let altPOV: String?
    let missing: Bool?
    let partialMissing: Bool?
    private(set) var apiIndex: Int? = nil
    private(set) var apiCount: Int? = nil

    var id: String {
        let base = youtubeId?.nonEmpty
            ?? sourceID?.nonEmpty
            ?? [title, date, duration, categories?.joined(separator: ",")].compactMap { $0?.nonEmpty }.joined(separator: "|")
        return "\(base)|\(apiIndex ?? 0)"
    }

    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled archive item"
    }

    var displayServices: [String] {
        let names = services ?? (service.map { [$0] } ?? [])
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    var archiveYear: String? {
        if let components = dateComponents { return String(components.year) }
        return segment?.first(where: { $0.count == 4 && Int($0) != nil })
    }

    var archiveMonth: String? {
        guard let components = dateComponents else { return nil }
        return String(format: "%02d", components.month)
    }

    private var dateComponents: (year: Int, month: Int)? {
        let parts = (date ?? "").split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        let year = parts[0] >= 1000 ? parts[0] : (parts[2] >= 1000 ? parts[2] : 2000 + parts[2])
        let month = parts[0] >= 1000 ? parts[1] : parts[0]
        guard (1...12).contains(month) else { return nil }
        return (year, month)
    }

    var isNew: Bool {
        guard let apiIndex, let apiCount else { return false }
        return apiIndex < min(10, apiCount)
    }

    var isUnavailable: Bool {
        if missing == true || partialMissing == true { return true }
        return displayServices.contains { service in
            let value = service.lowercased()
            return value.contains("missing") || value.contains("lost") || value.contains("partially")
        }
    }

    var availableSources: [ArchiveLink] {
        var links: [ArchiveLink] = []
        if let youtubeId = youtubeId?.nonEmpty,
           let url = URL(string: "https://www.youtube.com/watch?v=\(youtubeId)") {
            links.append(ArchiveLink(name: "YouTube", url: url))
        }
        for backup in backups ?? [] {
            guard let link = ArchiveLink(name: backup.name ?? "Archive source", urlString: backup.url ?? "", description: backup.description) else { continue }
            links.append(link)
        }
        var seen = Set<String>()
        return links.filter { seen.insert($0.url.absoluteString).inserted }
    }

    var thumbnailURL: URL? {
        for thumbnail in thumbnails ?? [] {
            if let url = Self.resolveImageURL(thumbnail) { return url }
        }
        if let id = youtubeId?.nonEmpty { return Self.youtubeThumbnail(id) }
        if let backupID = availableSources.compactMap(\.youtubeId).first { return Self.youtubeThumbnail(backupID) }
        return URL(string: "https://blueryai.xyz/temp.jpg")
    }

    var shortURL: URL {
        URL(string: "https://media.blueryai.xyz/s/\(Self.shortID(title: title ?? "", date: date ?? ""))")!
    }

    mutating func assignAPIIndex(_ index: Int, totalCount: Int) {
        apiIndex = index
        apiCount = totalCount
    }

    private static func resolveImageURL(_ value: String) -> URL? {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return URL(string: value, relativeTo: URL(string: "https://blueryai.xyz/"))?.absoluteURL
        }
        return url
    }

    private static func youtubeThumbnail(_ id: String) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg")
    }

    private static func shortID(title: String, date: String) -> String {
        let normalizedTitle = String(title.lowercased().filter { $0.isLetter || $0.isNumber })
        let units = Array((normalizedTitle + "|" + date).utf16)
        var h1: UInt32 = 0xdeadbeef
        var h2: UInt32 = 0x41c6ce57
        for unit in units {
            let character = UInt32(unit)
            h1 = (h1 ^ character) &* 2654435761
            h2 = (h2 ^ character) &* 1597334677
        }
        h1 = ((h1 ^ (h1 >> 16)) &* 2246822507) ^ ((h2 ^ (h2 >> 13)) &* 3266489909)
        h2 = ((h2 ^ (h2 >> 16)) &* 2246822507) ^ ((h1 ^ (h1 >> 13)) &* 3266489909)
        let value = ((UInt64(h2 & 0x1fffff)) << 32 | UInt64(h1)) % 2821109907456
        let encoded = String(value, radix: 36)
        return String(repeating: "0", count: max(0, 8 - encoded.count)) + encoded
    }

    enum CodingKeys: String, CodingKey {
        case sourceID = "id"
        case youtubeId
        case title
        case date
        case duration
        case description
        case categories
        case services
        case service
        case segment
        case thumbnails
        case backups
        case chat
        case altPOV = "alt_pov"
        case missing
        case partialMissing
        case apiIndex
        case apiCount
    }
}

struct ArchiveChat: Codable, Hashable {
    struct Source: Identifiable, Codable, Hashable {
        let name: String
        let url: URL
        var id: String { url.absoluteString }
    }

    let sources: [Source]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            if let url = URL(string: value), url.scheme?.lowercased() == "https" {
                sources = [Source(name: "Chat", url: url)]
            } else {
                sources = []
            }
            return
        }
        if let values = try? container.decode([String: String].self) {
            sources = values.keys.sorted().compactMap { key in
                guard let value = values[key], let url = URL(string: value), url.scheme?.lowercased() == "https" else { return nil }
                return Source(name: key, url: url)
            }
            return
        }
        throw DecodingError.typeMismatch(ArchiveChat.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a chat URL or map of chat URLs."))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if sources.count == 1, sources[0].name == "Chat" {
            try container.encode(sources[0].url.absoluteString)
        } else {
            let values = Dictionary(sources.map { ($0.name, $0.url.absoluteString) }, uniquingKeysWith: { first, _ in first })
            try container.encode(values)
        }
    }
}

struct ArchiveBackup: Codable, Hashable {
    let name: String?
    let url: String?
    let description: String?
}

struct ArchiveLink: Identifiable, Hashable {
    let name: String
    let url: URL
    var description: String? = nil

    init?(name: String, urlString: String, description: String? = nil) {
        guard let url = URL(string: urlString), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Archive source"
        self.url = url
        self.description = description
    }

    init(name: String, url: URL, description: String? = nil) {
        self.name = name
        self.url = url
        self.description = description
    }

    var id: String { url.absoluteString }

    var youtubeId: String? {
        guard let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let candidate: String?
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            candidate = parts.first
        } else if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
            candidate = query
        } else if let embedIndex = parts.firstIndex(where: { ["embed", "shorts", "live", "v"].contains($0) }), parts.indices.contains(embedIndex + 1) {
            candidate = parts[embedIndex + 1]
        } else {
            candidate = nil
        }
        guard let candidate, candidate.count == 11 else { return nil }
        return candidate
    }

    var twitchPlayerURL: URL? {
        guard let host = url.host?.lowercased().replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: ""),
              host == "twitch.tv" || host == "clips.twitch.tv" || host == "player.twitch.tv" else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host == "clips.twitch.tv" ? "clips.twitch.tv" : "player.twitch.tv"
        var query: [URLQueryItem] = [URLQueryItem(name: "parent", value: "blueryai.xyz"), URLQueryItem(name: "autoplay", value: "false")]
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "clips.twitch.tv", let clip = parts.first {
            components.path = "/embed"
            query.append(URLQueryItem(name: "clip", value: clip))
        } else if host == "twitch.tv", parts.first == "videos", parts.count > 1 {
            components.path = "/"
            query.append(URLQueryItem(name: "video", value: "v" + parts[1].replacingOccurrences(of: "v", with: "")))
            if let timestamp = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "t" })?.value {
                query.append(URLQueryItem(name: "time", value: timestamp))
            }
        } else if host == "player.twitch.tv" {
            components.path = "/"
            if let video = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "video" })?.value {
                query.append(URLQueryItem(name: "video", value: video))
            } else if let channel = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "channel" })?.value {
                query.append(URLQueryItem(name: "channel", value: channel))
            } else { return nil }
        } else if let channel = parts.first {
            components.path = "/"
            query.append(URLQueryItem(name: "channel", value: channel))
        } else { return nil }
        components.queryItems = query
        return components.url
    }

    var playbackURL: URL {
        if let youtubeId, let url = URL(string: "https://www.youtube-nocookie.com/embed/\(youtubeId)?playsinline=1&rel=0&autoplay=0") { return url }
        if let twitchPlayerURL { return twitchPlayerURL }
        if isDirectMedia, let directURL = downloadableURL { return directURL }
        if url.host?.lowercased() == "archive.org" {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count > 1, ["details", "download", "embed"].contains(parts[0]) {
                return URL(string: "https://archive.org/embed/\(parts[1])") ?? url
            }
        }
        return url
    }

    var archiveOrgIdentifier: String? {
        guard let host = url.host?.lowercased(), host == "archive.org" || host == "www.archive.org" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count > 1, ["details", "embed", "download"].contains(parts[0]) else { return nil }
        return parts[1]
    }

    var canDownload: Bool { downloadableURL != nil || archiveOrgIdentifier != nil }

    var estimatedByteCount: Int64? {
        let filename = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard let hint = filename.split(separator: "-").first else { return nil }
        let lower = hint.lowercased()
        let multiplier: Double
        if lower.hasSuffix("gb") { multiplier = 1_073_741_824 }
        else if lower.hasSuffix("mb") { multiplier = 1_048_576 }
        else if lower.hasSuffix("kb") { multiplier = 1_024 }
        else { return nil }
        let number = lower.dropLast(2)
        guard let value = Double(String(number)), value > 0 else { return nil }
        return Int64(value * multiplier)
    }

    var isDirectMedia: Bool {
        let host = url.host?.lowercased() ?? ""
        let ext = url.pathExtension.lowercased()
        if host.contains("googlevideo.com") && url.path.contains("videoplayback") { return true }
        return ["mp4", "m4v", "mov", "m3u8", "mp3", "m4a", "aac", "wav"].contains(ext)
    }

    var downloadableURL: URL? {
        let host = url.host?.lowercased() ?? ""
        if host == "dropbox.com" || host.hasSuffix(".dropbox.com") || host == "dropboxusercontent.com" || host.hasSuffix(".dropboxusercontent.com") {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            var query = (components.queryItems ?? []).filter { $0.name != "dl" && $0.name != "raw" }
            query.append(URLQueryItem(name: "dl", value: "1"))
            components.queryItems = query
            return components.url
        }
        if host.hasSuffix(".gofile.io") && url.path.contains("/download/direct/") { return url }
        if host == "gofile.io", url.path.contains("/download/direct/") { return url }
        if host == "archive.org", url.path.hasPrefix("/download/"), !url.pathExtension.isEmpty { return url }
        if isDirectMedia { return url }
        let ext = url.pathExtension.lowercased()
        if ["zip", "7z", "rar", "pdf", "csv", "json", "txt", "jpg", "jpeg", "png", "webp"].contains(ext) { return url }
        return nil
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
