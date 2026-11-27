import SwiftUI

@main
struct BlueryaiArchiveApp: App {
    @StateObject private var store = TabStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}

struct RootView: View {
    @ObservedObject var store: TabStore

    var body: some View {
        if let tab = store.selected {
            BrowserScreen(store: store, tab: tab)
                .id(tab.id)
        }
    }
}
