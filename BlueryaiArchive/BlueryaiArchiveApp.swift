import SwiftUI

@main
struct BlueryaiArchiveApp: App {
    @StateObject private var archive = ArchiveStore()
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var playback = ArchivePlaybackManager.shared

    var body: some Scene {
        WindowGroup {
            ArchiveTabsView()
                .environmentObject(archive)
                .environmentObject(downloads)
                .environmentObject(playback)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.58, green: 0.74, blue: 0.94))
        }
    }
}
