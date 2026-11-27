import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, vods, videos, clips, music, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .vods: return "VODs"
        case .videos: return "Videos"
        case .clips: return "Clips"
        case .music: return "Music"
        case .all: return "All"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .vods: return "play.rectangle.fill"
        case .videos: return "film.fill"
        case .clips: return "scissors"
        case .music: return "music.note"
        case .all: return "square.grid.2x2.fill"
        }
    }

    var itemType: ItemType? {
        switch self {
        case .vods: return .vods
        case .videos: return .videos
        case .clips: return .clips
        case .music: return .music
        case .home, .all: return nil
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { HomeView() }
                default:
                    NavigationStack { BrowseView(type: selectedTab.itemType) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selectedTab: $selectedTab)
        }
        .background(Color(hex: "#0d1117").ignoresSafeArea())
    }
}