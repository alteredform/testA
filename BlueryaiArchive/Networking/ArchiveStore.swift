import Foundation

@MainActor
final class ArchiveStore: ObservableObject {
    static let shared = ArchiveStore()

    @Published private(set) var items: [ArchiveItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await APIClient.shared.fetchItems()
            didLoad = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func items(for type: ItemType?) -> [ArchiveItem] {
        guard let type else { return items }
        return items.filter { $0.type == type }
    }
}