import SwiftUI

@main
struct BlueryaiArchiveApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}