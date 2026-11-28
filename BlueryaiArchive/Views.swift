import QuickLook
import SwiftUI

@MainActor
final class ArchiveStore: ObservableObject {
    @Published private(set) var items: [ArchiveItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = ArchiveService()
    private var hasLoaded = false

    var recentItems: [ArchiveItem] {
        Array(items.prefix(10))
    }

    var allServices: [String] {
        Array(Set(items.flatMap(\.displayServices))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var archiveYears: [String] {
        Array(Set(items.compactMap(\.archiveYear))).sorted(by: >)
    }

    func archiveMonths(for year: String) -> [String] {
        Array(Set(items.filter { $0.archiveYear == year }.compactMap(\.archiveMonth))).sorted()
    }

    func monthName(_ number: String) -> String {
        guard let month = Int(number), (1...12).contains(month) else { return number }
        let names = DateFormatter().monthSymbols ?? []
        return names.indices.contains(month - 1) ? names[month - 1] : number
    }

    func load(force: Bool = false) async {
        guard !isLoading, force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await service.loadItems()
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filteredItems(category: ArchiveCategory, query: String, service: String? = nil, year: String? = nil, month: String? = nil, newOnly: Bool = false, unavailableOnly: Bool = false) -> [ArchiveItem] {
        items.filter { item in
            let matchesCategory: Bool
            if category == .all {
                matchesCategory = true
            } else {
                matchesCategory = item.categories?.contains(where: {
                    $0.localizedCaseInsensitiveCompare(category.siteValue) == .orderedSame
                }) ?? false
            }
            let matchesService = service.map { selected in
                item.displayServices.contains { $0.localizedCaseInsensitiveCompare(selected) == .orderedSame }
            } ?? true
            let matchesYear = year.map { item.archiveYear == $0 } ?? true
            let matchesMonth = month.map { item.archiveMonth == $0 } ?? true
            let matchesNew = !newOnly || item.isNew
            let matchesAvailability = !unavailableOnly || item.isUnavailable
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchable = [
                item.title,
                item.date,
                item.duration,
                item.description,
                item.services?.joined(separator: " "),
                item.service,
                item.categories?.joined(separator: " "),
                item.segment?.joined(separator: " "),
                item.backups?.map { [$0.name, $0.url, $0.description].compactMap { $0 }.joined(separator: " ") }.joined(separator: " ")
            ].compactMap { $0 }.joined(separator: " ")
            return matchesCategory && matchesService && matchesYear && matchesMonth && matchesNew && matchesAvailability && (term.isEmpty || searchable.localizedCaseInsensitiveContains(term))
        }
    }
}

enum ArchiveTab: Hashable {
    case home
    case all
    case downloads
}

enum ArchiveSortOrder: String, CaseIterable, Identifiable, Equatable, Hashable {
    case newest
    case oldest
    case title

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .title: return "Title"
        }
    }
}

enum ArchiveCategory: String, CaseIterable, Identifiable, Equatable, Hashable {
    case all = "All"
    case vods = "VODs"
    case videos = "Videos"
    case clips = "Clips"
    case music = "Music"
    case shorts = "Shorts"

    var id: String { rawValue }
    var siteValue: String { self == .vods ? "VODS" : rawValue }
}

struct ArchiveTabsView: View {
    @EnvironmentObject private var archive: ArchiveStore
    @EnvironmentObject private var downloads: DownloadManager
    @State private var selectedTab: ArchiveTab = .home
    @State private var selectedCategory: ArchiveCategory = .all

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WebsiteHomeView(selectedTab: $selectedTab, selectedCategory: $selectedCategory)
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(ArchiveTab.home)

            NavigationStack {
                AllArchiveView(selectedCategory: $selectedCategory)
            }
            .tabItem { Label("All", systemImage: "square.grid.2x2") }
            .tag(ArchiveTab.all)

            NavigationStack {
                DownloadsView()
            }
            .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            .tag(ArchiveTab.downloads)
        }
        .task { await archive.load() }
        .overlay(alignment: .top) {
            if let toast = downloads.toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloads.toast)
    }
}

private struct AllArchiveView: View {
    @EnvironmentObject private var archive: ArchiveStore
    @Binding var selectedCategory: ArchiveCategory
    @State private var searchText = ""
    @State private var selectedService: String?
    @State private var selectedYear: String?
    @State private var selectedMonth: String?
    @State private var newOnly = false
    @State private var unavailableOnly = false
    @State private var sortOrder: ArchiveSortOrder = .newest
    @State private var gridMode = false

    private var results: [ArchiveItem] {
        let filtered = archive.filteredItems(category: selectedCategory, query: searchText, service: selectedService, year: selectedYear, month: selectedMonth, newOnly: newOnly, unavailableOnly: unavailableOnly)
        switch sortOrder {
        case .newest: return filtered
        case .oldest: return Array(filtered.reversed())
        case .title: return filtered.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        }
    }

    private var pageTitle: String {
        switch selectedCategory {
        case .all: return "All Videos"
        case .music: return "Music Videos"
        case .shorts: return "Shorts"
        case .videos: return "Videos"
        case .clips: return "Clips"
        case .vods: return "VODs"
        }
    }

    private var pageDescription: String {
        switch selectedCategory {
        case .all: return "Every VOD, video, clip and music video in the Blueryai Archive."
        case .music: return "Blueryai music and freestyles, archived from BlueRyai Music and more."
        case .shorts: return "Short-form videos preserved from Blueryai’s channels."
        case .videos: return "Community-edited videos from deleted and private channels, plus official uploads."
        case .clips: return "Clips from Blueryai streams and videos."
        case .vods: return "Full recordings of Blueryai streams saved or recovered from across the years."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ArchiveHeader(subtitle: "THE COMPLETE COLLECTION")
                VStack(alignment: .leading, spacing: 6) {
                    Text(pageTitle)
                        .font(.system(size: 34, weight: .regular, design: .serif))
                    Text(pageDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search titles, dates, categories…", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(12)
                .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("Filter by type", systemImage: "line.3.horizontal.decrease")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(archive.isLoading ? "Loading" : "\(results.count.formatted()) of \(archive.items.count.formatted()) items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(ArchiveCategory.allCases) { category in
                                FilterChip(title: category.rawValue, selected: selectedCategory == category) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All sources", selected: selectedService == nil) { selectedService = nil }
                            ForEach(archive.allServices, id: \.self) { service in
                                FilterChip(title: service, selected: selectedService == service) {
                                    selectedService = selectedService == service ? nil : service
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Browse by year and month")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All years", selected: selectedYear == nil) {
                                    selectedYear = nil
                                    selectedMonth = nil
                                }
                                ForEach(archive.archiveYears, id: \.self) { year in
                                    FilterChip(title: year, selected: selectedYear == year) {
                                        selectedYear = year
                                        selectedMonth = nil
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        if let selectedYear {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    FilterChip(title: "All months", selected: selectedMonth == nil) { selectedMonth = nil }
                                    ForEach(archive.archiveMonths(for: selectedYear), id: \.self) { month in
                                        FilterChip(title: archive.monthName(month), selected: selectedMonth == month) { selectedMonth = month }
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                    }

                    HStack(spacing: 8) {
                        FilterChip(title: "Recently added", selected: newOnly) { newOnly.toggle() }
                        FilterChip(title: "Unavailable", selected: unavailableOnly) { unavailableOnly.toggle() }
                        Spacer(minLength: 0)
                        Menu {
                            ForEach(ArchiveSortOrder.allCases) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    if sortOrder == order { Label(order.label, systemImage: "checkmark") }
                                    else { Text(order.label) }
                                }
                            }
                        } label: {
                            Label(sortOrder.label, systemImage: "arrow.up.arrow.down")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.archiveBlue)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(Color.archiveSurface, in: Capsule())
                        }
                        Button { gridMode.toggle() } label: {
                            Image(systemName: gridMode ? "list.bullet" : "square.grid.2x2")
                                .font(.caption)
                                .foregroundStyle(Color.archiveBlue)
                                .frame(width: 31, height: 31)
                                .background(Color.archiveSurface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(gridMode ? "Show list" : "Show grid")
                    }
                }
                .padding(.top, 7)

                if archive.isLoading && archive.items.isEmpty {
                    LoadingMessage()
                } else if let message = archive.errorMessage, archive.items.isEmpty {
                    ErrorMessage(message: message) { Task { await archive.load(force: true) } }
                } else if results.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                        Text("No items found").font(.headline)
                        Text("Try another title or category.").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else if gridMode {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(results) { item in
                            NavigationLink(value: item) { ArchiveItemTile(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { item in
                            NavigationLink(value: item) { ArchiveItemRow(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.archiveBackground)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .navigationDestination(for: ArchiveItem.self) { item in
            NativeArchiveItemDetailView(item: item)
        }
        .refreshable { await archive.load(force: true) }
    }
}

private struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @State private var previewURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArchiveHeader(subtitle: "SAVED ON THIS DEVICE")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Downloads")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                    Text("Files saved from archive sources.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !downloads.downloads.filter({ $0.phase != .complete }).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Download activity").font(.headline)
                        ForEach(downloads.downloads.filter { $0.phase != .complete }) { download in
                            DownloadProgressRow(download: download)
                        }
                    }
                }
                if downloads.files.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle").font(.system(size: 29)).foregroundStyle(.secondary)
                        Text(downloads.downloads.isEmpty ? "No downloads yet" : "No saved files yet").font(.headline)
                        Text("Download a file from an archive item and it will appear here.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(downloads.files, id: \.self) { url in
                            Button { previewURL = url } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: fileIcon(for: url))
                                        .font(.title3)
                                        .foregroundStyle(Color.archiveBlue)
                                        .frame(width: 42, height: 42)
                                        .background(Color.archiveBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(url.lastPathComponent).font(.subheadline.weight(.medium)).lineLimit(2)
                                        Text(downloads.details(for: url)).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                                Button(role: .destructive) { downloads.delete(url) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color.archiveBackground)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .onAppear { downloads.refresh() }
        .quickLookPreview($previewURL)
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4", "mov", "mkv", "webm", "m4v": return "film"
        case "mp3", "m4a", "wav", "flac", "ogg": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo"
        case "txt", "json", "csv", "md": return "doc.text"
        default: return "doc"
        }
    }
}

private struct ArchiveHeader: View {
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image("SiteFavicon")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.archiveBlue.opacity(0.22)))
            VStack(alignment: .leading, spacing: 4) {
                Text("BLUERYAI ARCHIVE").font(.caption2.weight(.bold)).tracking(1.1)
                Text(subtitle).font(.system(size: 9, weight: .medium)).tracking(0.7).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

private struct SectionHeading: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kicker).font(.system(size: 9, weight: .bold)).tracking(1.25).foregroundStyle(Color.archiveBlue)
            Text(title).font(.headline.weight(.semibold))
        }
        .padding(.vertical, 3)
    }
}

private struct CollectionCard: View {
    let category: ArchiveCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.archiveBlue)
                .frame(width: 32, height: 32)
                .background(Color.archiveBlue.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
            Text(category.rawValue).font(.subheadline.weight(.semibold))
            Text("Explore the collection").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
        .padding(14)
        .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07)))
        .contentShape(RoundedRectangle(cornerRadius: 15))
    }

    private var icon: String {
        switch category {
        case .vods: return "play.rectangle"
        case .videos: return "film"
        case .clips: return "scissors"
        case .music: return "music.note"
        case .shorts: return "play.square.stack"
        case .all: return "square.grid.2x2"
        }
    }
}

struct ArchiveItemRow: View {
    let item: ArchiveItem

    var body: some View {
        HStack(spacing: 12) {
            ArchiveThumbnail(url: item.thumbnailURL, height: 62, duration: item.duration)
                .frame(width: 104)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    Text(item.displayTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if item.isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(Color.green)
                    }
                }
                HStack(spacing: 5) {
                    Text(item.date ?? "Date unknown")
                    if let category = item.categories?.first {
                        Text("·")
                        Text(category)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if item.isUnavailable {
                    Text("Partial or unavailable").font(.caption2).foregroundStyle(.red.opacity(0.85))
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

private struct ArchiveThumbnail: View {
    let url: URL?
    let height: CGFloat
    var duration: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if case .failure = phase {
                            AsyncImage(url: URL(string: "https://blueryai.xyz/temp.jpg")) { fallback in
                                if let image = fallback.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    placeholder
                                }
                            }
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if let duration, !duration.isEmpty {
                Text(duration)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                    .padding(5)
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Rectangle().fill(Color.archiveSurface)
            .overlay(Image(systemName: "play.fill").font(.caption).foregroundStyle(Color.archiveBlue.opacity(0.8)))
    }
}

private struct LoadingMessage: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Loading the archive…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct ErrorMessage: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try again", action: retry).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.archiveBlue : Color.archiveMuted)
                .background(selected ? Color.archiveBlue.opacity(0.15) : Color.archiveSurface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.archiveBlue.opacity(0.45) : Color.archiveBorder))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ArchiveItemTile: View {
    let item: ArchiveItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArchiveThumbnail(url: item.thumbnailURL, height: 120, duration: item.duration)
            Text(item.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.archiveText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text([item.date, item.categories?.first].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(Color.archiveMuted)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.archiveBorder))
    }
}

private struct DownloadProgressRow: View {
    @EnvironmentObject private var downloads: DownloadManager
    let download: ArchiveDownload

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(download.filename).font(.caption.weight(.semibold)).lineLimit(2)
                    Text(download.sourceName).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                switch download.phase {
                case .resolving, .downloading:
                    Button { downloads.cancel(download.id) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel download")
                case .failed, .cancelled:
                    Button { downloads.dismiss(download.id) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss download")
                case .complete:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            switch download.phase {
            case .resolving:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Finding a downloadable video…").font(.caption2).foregroundStyle(.secondary)
                }
            case .downloading:
                if let fraction = download.fractionCompleted {
                    ProgressView(value: fraction)
                } else {
                    ProgressView()
                }
                Text(download.progressSummary).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            case .failed(let message):
                Text("Failed: \(message)").font(.caption2).foregroundStyle(.red)
                Button("Retry") { downloads.retry(download.id) }.font(.caption2.weight(.semibold))
            case .cancelled:
                Text("Cancelled · \(download.progressSummary)").font(.caption2).foregroundStyle(.secondary)
                Button("Retry") { downloads.retry(download.id) }.font(.caption2.weight(.semibold))
            case .complete:
                Text(download.progressSummary).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 10))
    }
}

extension Color {
    static let archiveBackground = Color(red: 0.051, green: 0.067, blue: 0.090)
    static let archiveSurface = Color(red: 0.086, green: 0.106, blue: 0.133)
    static let archiveBorder = Color(red: 0.129, green: 0.153, blue: 0.184)
    static let archiveText = Color(red: 0.788, green: 0.820, blue: 0.851)
    static let archiveMuted = Color(red: 0.545, green: 0.580, blue: 0.620)
    static let archiveBlue = Color(red: 0.345, green: 0.650, blue: 1)
}
