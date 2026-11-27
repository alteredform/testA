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
        Array(items.suffix(10).reversed())
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

    func filteredItems(category: ArchiveCategory, query: String) -> [ArchiveItem] {
        items.filter { item in
            let matchesCategory: Bool
            if category == .all {
                matchesCategory = true
            } else {
                matchesCategory = item.categories?.contains(where: {
                    $0.localizedCaseInsensitiveCompare(category.siteValue) == .orderedSame
                }) ?? false
            }
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchable = [
                item.title,
                item.date,
                item.description,
                item.services?.joined(separator: " "),
                item.service,
                item.categories?.joined(separator: " ")
            ].compactMap { $0 }.joined(separator: " ")
            return matchesCategory && (term.isEmpty || searchable.localizedCaseInsensitiveContains(term))
        }
    }
}

enum ArchiveTab: Hashable {
    case home
    case all
    case downloads
}

enum ArchiveCategory: String, CaseIterable, Identifiable, Equatable, Hashable {
    case all = "All"
    case vods = "VODs"
    case videos = "Videos"
    case clips = "Clips"
    case music = "Music"

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
                HomeView(selectedTab: $selectedTab, selectedCategory: $selectedCategory)
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

private struct HomeView: View {
    @EnvironmentObject private var archive: ArchiveStore
    @Binding var selectedTab: ArchiveTab
    @Binding var selectedCategory: ArchiveCategory

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ArchiveHeader(subtitle: "THE COLLECTION, ALL IN ONE PLACE")

                VStack(alignment: .leading, spacing: 16) {
                    Text("A COMMUNITY-BUILT COLLECTION")
                        .font(.caption2.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.archiveBlue)
                    Text("The Blueryai\nArchive")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundStyle(.white)
                    Text("An ongoing archive of streams, videos, clips and music — gathered in one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        selectedCategory = .all
                        selectedTab = .all
                    } label: {
                        Label("Explore the archive", systemImage: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.archiveBlue, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(archive.items.isEmpty ? "—" : archive.items.count.formatted())
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                        Text("items in the archive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.17, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08)))
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(kicker: "FIND YOUR NEXT WATCH", title: "Browse by collection")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(ArchiveCategory.allCases.dropFirst())) { category in
                            Button {
                                selectedCategory = category
                                selectedTab = .all
                            } label: {
                                CollectionCard(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading(kicker: "FRESH FROM THE ARCHIVE", title: "Recently added")
                    if archive.isLoading && archive.items.isEmpty {
                        LoadingMessage()
                    } else if let message = archive.errorMessage, archive.items.isEmpty {
                        ErrorMessage(message: message) { Task { await archive.load(force: true) } }
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(archive.recentItems) { item in
                                NavigationLink(value: item) { ArchiveItemRow(item: item) }
                                    .buttonStyle(.plain)
                            }
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
            ArchiveItemDetailView(item: item)
        }
        .refreshable { await archive.load(force: true) }
    }
}

private struct AllArchiveView: View {
    @EnvironmentObject private var archive: ArchiveStore
    @Binding var selectedCategory: ArchiveCategory
    @State private var searchText = ""

    private var results: [ArchiveItem] {
        archive.filteredItems(category: selectedCategory, query: searchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ArchiveHeader(subtitle: "THE COMPLETE COLLECTION")
                VStack(alignment: .leading, spacing: 6) {
                    Text("All content")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                    Text("Browse everything preserved in the archive.")
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Filter by type", systemImage: "line.3.horizontal.decrease")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(archive.isLoading ? "Loading" : "\(results.count.formatted()) items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(ArchiveCategory.allCases) { category in
                                Button { selectedCategory = category } label: {
                                    Text(category.rawValue)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(selectedCategory == category ? Color.archiveBlue : Color.secondary)
                                        .background(selectedCategory == category ? Color.archiveBlue.opacity(0.16) : Color.archiveSurface, in: Capsule())
                                        .overlay(Capsule().stroke(selectedCategory == category ? Color.archiveBlue.opacity(0.5) : Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
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
            ArchiveItemDetailView(item: item)
        }
        .refreshable { await archive.load(force: true) }
    }
}

private struct ArchiveItemDetailView: View {
    @EnvironmentObject private var downloads: DownloadManager
    let item: ArchiveItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArchiveThumbnail(url: item.thumbnailURL, height: 220, duration: item.duration)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(item.categories ?? [], id: \.self) { category in
                            Text(category)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .foregroundStyle(Color.archiveBlue)
                                .background(Color.archiveBlue.opacity(0.13), in: Capsule())
                        }
                    }
                    Text(item.displayTitle)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        if let date = item.date { Label(date, systemImage: "calendar").lineLimit(1) }
                        ForEach(item.displayServices.prefix(2), id: \.self) { Text($0).lineLimit(1) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(kicker: "WATCH & DOWNLOAD", title: "Available sources")
                    if item.availableSources.isEmpty {
                        Text("No sources are listed for this item yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(item.availableSources) { source in
                            SourceRow(source: source)
                        }
                    }
                }
                Text("Downloads are saved to the Files app under On My iPhone › Blueryai Archive.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Color.archiveBackground)
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let shareURL = item.availableSources.first?.url {
                    ShareLink(item: shareURL) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
    }
}

private struct SourceRow: View {
    @EnvironmentObject private var downloads: DownloadManager
    let source: ArchiveLink

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.name.localizedCaseInsensitiveContains("youtube") ? "play.rectangle.fill" : "arrow.up.right.square")
                .font(.system(size: 17))
                .foregroundStyle(Color.archiveBlue)
                .frame(width: 38, height: 38)
                .background(Color.archiveBlue.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(source.description ?? (source.downloadableURL == nil ? "Open archive source" : "Available to watch or download"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Link(destination: source.url) {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open \(source.name)")
            if let fileURL = source.downloadableURL {
                Button { downloads.download(source) } label: {
                    if downloads.activeDownloads.contains(fileURL.absoluteString) {
                        ProgressView().controlSize(.small).frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.down.to.line")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.archiveBlue)
                            .frame(width: 32, height: 32)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download from \(source.name)")
            }
        }
        .padding(10)
        .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 14))
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
                if downloads.files.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle").font(.system(size: 29)).foregroundStyle(.secondary)
                        Text("No downloads yet").font(.headline)
                        Text("Download a file from an archive item and it will appear here.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
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
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Color(red: 0.13, green: 0.20, blue: 0.29))
                RoundedRectangle(cornerRadius: 11).stroke(Color.archiveBlue.opacity(0.22))
                Text("B").font(.system(size: 22, weight: .regular, design: .serif)).foregroundStyle(Color.archiveBlue)
            }
            .frame(width: 38, height: 38)
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
        case .all: return "square.grid.2x2"
        }
    }
}

private struct ArchiveItemRow: View {
    let item: ArchiveItem

    var body: some View {
        HStack(spacing: 12) {
            ArchiveThumbnail(url: item.thumbnailURL, height: 62, duration: item.duration)
                .frame(width: 104)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    Text(item.date ?? "Date unknown")
                    if let category = item.categories?.first {
                        Text("·")
                        Text(category)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if item.missing == true || item.partialMissing == true {
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

private extension Color {
    static let archiveBackground = Color(red: 0.047, green: 0.063, blue: 0.086)
    static let archiveSurface = Color(red: 0.083, green: 0.103, blue: 0.133)
    static let archiveBlue = Color(red: 0.62, green: 0.77, blue: 0.94)
}
