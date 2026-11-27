import Foundation

enum ItemType: String, Codable, CaseIterable, Identifiable, Hashable {
    case vods, videos, clips, music
    var id: String { rawValue }

    /// Lenient parsing — the API may use singular/alternate names.
    init?(loose s: String) {
        switch s.lowercased() {
        case "vod", "vods", "stream", "streams", "vodstreams": self = .vods
        case "video", "videos", "edited": self = .videos
        case "clip", "clips", "shorts": self = .clips
        case "music", "songs", "audio", "freestyle", "freestyles": self = .music
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .vods: return "VODs"
        case .videos: return "Videos"
        case .clips: return "Clips"
        case .music: return "Music"
        }
    }

    var icon: String {
        switch self {
        case .vods: return "play.rectangle"
        case .videos: return "film"
        case .clips: return "scissors"
        case .music: return "music.note"
        }
    }
}