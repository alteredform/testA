
import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case dateDesc, dateAsc, nameAsc, nameDesc, durationAsc, durationDesc
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateDesc:     return "Newest First"
        case .dateAsc:      return "Oldest First"
        case .nameAsc:      return "Name A-Z"
        case .nameDesc:     return "Name Z-A"
        case .durationAsc:  return "Shortest First"
        case .durationDesc: return "Longest First"
        }
    }
}

struct BrowseView: View {
    let type: ItemType?

    @ObservedObject private var store = ArchiveStore.shared

    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDesc
    @State private var selectedServices: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedOther: Set<String> = []
    @State private var showFilters = false

    @State private var randomItem: ArchiveItem?
    @State private var showRandom = false

    var body: some View {
        content
            .navigationTitle(type?.displayName ?? "All")
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                        }
                        Button {
                            if let pick = filteredItems.randomElement() {
                                randomItem = pick
                                showRandom = true
                            }
                        } label: {
                            Label("Random", systemImage: "shuffle")
                        }
                        Button { showFilters = true } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(
                    items: store.items(for: type),
                    selectedServices: $selectedServices,
                    selectedCategories: $selectedCategories,
                    selectedOther: $selectedOther
                )
            }
            .navigationDestination(for: ArchiveItem.self) { item in
                ItemDetailView(item: item)
            }
            .navigationDestination(isPresented: $showRandom) {
                if let randomItem {
                    ItemDetailView(item: randomItem)
                }
            }
            .task {
                await store.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.items.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.errorMessage, store.items.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Retry") {
                    Task { await store.reload() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredItems.isEmpty {
            Text("No items found")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            ItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Filtering

    private var filteredItems: [ArchiveItem] {
        var result = store.items(for: type)

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !selectedServices.isEmpty {
            result = result.filter {
                !selectedServices.isDisjoint(with: Set($0.services))
            }
        }
        if !selectedCategories.isEmpty {
            result = result.filter {
                !selectedCategories.isDisjoint(with: Set($0.tags))
            }
        }
        if !selectedOther.isEmpty {
            result = result.filter { item in
                var matched = false
                if selectedOther.contains("Missing"), item.isMissing { matched = true }
                if selectedOther.contains("New"), item.isNew { matched = true }
                return matched
            }
        }

        switch sortOption {
        case .dateDesc:
            result.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        case .dateAsc:
            result.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        case .nameAsc:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .durationAsc:
            result.sort { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .durationDesc:
            result.sort { ($0.duration ?? 0) > ($1.duration ?? 0) }
        }
        return result
    }
}