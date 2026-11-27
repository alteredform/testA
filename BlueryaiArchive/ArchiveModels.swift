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
    let thumbnails: [String]?
    let backups: [ArchiveBackup]?
    let missing: Bool?
    let partialMissing: Bool?

    var id: String {
        youtubeId ?? sourceID ?? "\(title ?? "archive-item")-\(date ?? "")"
    }

    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled archive item"
    }

    var thumbnailURL: URL? {
        if let thumbnail = thumbnails?.first, let url = URL(string: thumbnail), url.scheme == "https" {
            return url
        }
        if let youtubeId {
            return URL(string: "https://img.youtube.com/vi/\(youtubeId)/mqdefault.jpg")
        }
        return nil
    }

    var displayServices: [String] {
        let names = services ?? (service.map { [$0] } ?? [])
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    var availableSources: [ArchiveLink] {
        var links: [ArchiveLink] = []
        if let youtubeId, let url = URL(string: "https://www.youtube.com/watch?v=\(youtubeId)") {
            links.append(ArchiveLink(name: "YouTube", url: url))
        }
        for backup in backups ?? [] {
            guard let rawURL = backup.url, let url = URL(string: rawURL),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { continue }
            let name = backup.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Archive source"
            links.append(ArchiveLink(name: name, url: url, description: backup.description))
        }
        var seen = Set<String>()
        return links.filter { seen.insert($0.url.absoluteString).inserted }
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
        case thumbnails
        case backups
        case missing
        case partialMissing
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

    var id: String { url.absoluteString }

    var downloadableURL: URL? {
        guard let host = url.host?.lowercased() else { return nil }
        if host == "dropbox.com" || host.hasSuffix(".dropbox.com") || host == "dropboxusercontent.com" || host.hasSuffix(".dropboxusercontent.com") {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            var query = (components.queryItems ?? []).filter { $0.name != "dl" && $0.name != "raw" }
            query.append(URLQueryItem(name: "dl", value: "1"))
            components.queryItems = query
            return components.url
        }
        if (host == "gofile.io" || host.hasSuffix(".gofile.io")), url.path.contains("/download/direct/") {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            components.queryItems = (components.queryItems ?? []).filter { $0.name != "inline" }
            return components.url
        }
        if host == "archive.org", url.path.hasPrefix("/download/"),
           ["mp4", "m4v", "mkv", "webm", "mov", "avi", "zip", "mp3", "pdf"].contains(url.pathExtension.lowercased()) {
            return url
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
