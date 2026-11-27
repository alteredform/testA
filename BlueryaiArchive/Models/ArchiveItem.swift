import Foundation

struct ArchiveItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let type: ItemType
    let dateString: String?
    let date: Date?
    let youtubeId: String?
    let thumbnails: [String]
    let backups: [Backup]
    let description: String?
    let chat: [String: String]
    let tags: [String]
    let isMissing: Bool
    let isNew: Bool

    // MARK: - Display helpers

    var primaryThumbnailURL: URL? {
        if let yt = youtubeId {
            return URL(string: "https://img.youtube.com/vi/\(yt)/hqdefault.jpg")
        }
        return thumbnails.first.flatMap(APIConfig.resolveAssetURL)
    }

    var formattedDate: String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    var availableBackups: [Backup] { backups.filter { !$0.unavailable } }

    var defaultBackup: Backup? {
        // Prefer direct media, then YouTube, then anything usable.
        availableBackups.first(where: { $0.isDirectMedia })
            ?? availableBackups.first(where: { $0.isYouTube })
            ?? availableBackups.first
    }

    // MARK: - Decoding

    enum CodingKeys: String, CodingKey {
        case id, title, type, category, kind, date, youtubeId, thumbnails,
             backups, sources, description, chat, tags, isMissing, isNew
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        title      = (try? c.decode(String.self, forKey: .title)) ?? "Untitled"
        dateString =  try? c.decode(String.self, forKey: .date)
        youtubeId  =  try? c.decode(String.self, forKey: .youtubeId)
        thumbnails = (try? c.decode([String].self, forKey: .thumbnails)) ?? []
        description = try? c.decode(String.self, forKey: .description)
        chat       = (try? c.decode([String: String].self, forKey: .chat)) ?? [:]
        tags       = (try? c.decode([String].self, forKey: .tags)) ?? []
        isMissing  = (try? c.decode(Bool.self, forKey: .isMissing)) ?? false
        isNew      = (try? c.decode(Bool.self, forKey: .isNew)) ?? false

        // "backups" is the canonical name; "sources" is a fallback.
        if let b = try? c.decode([Backup].self, forKey: .backups) {
            backups = b
        } else if let s = try? c.decode([Backup].self, forKey: .sources) {
            backups = s
        } else {
            backups = []
        }

        let rawType = (try? c.decode(String.self, forKey: .type))
            ?? (try? c.decode(String.self, forKey: .category))
            ?? (try? c.decode(String.self, forKey: .kind))
            ?? "vods"
        type = ItemType(loose: rawType) ?? .vods

        // Date — accept ISO8601, yyyy-MM-dd, MM.dd.yyyy
        if let s = dateString {
            let iso = ISO8601DateFormatter()
            let ymd = DateFormatter(); ymd.dateFormat = "yyyy-MM-dd"
            let mdy = DateFormatter(); mdy.dateFormat = "MM.dd.yyyy"
            date = iso.date(from: s) ?? ymd.date(from: s) ?? mdy.date(from: s)
        } else {
            date = nil
        }

        // Stable ID — mirrors share.mjs genId
        let provided = try? c.decode(String.self, forKey: .id)
        id = provided
            ?? youtubeId
            ?? ArchiveItem.genId(title: title, date: dateString)
    }

    static func genId(title: String, date: String?) -> String {
        let t = String(title
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
            .prefix(20))
        let d = String((date ?? "")
            .replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            .prefix(6))
        return "\(t)_\(d)"
    }
}