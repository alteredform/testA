import Foundation

enum ItemType: String, Codable, CaseIterable, Identifiable, Hashable {
    case vods, videos, clips, music

    var id: String { rawValue }

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