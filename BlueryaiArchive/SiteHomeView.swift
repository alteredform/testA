import SwiftUI

struct WebsiteHomeView: View {
    @EnvironmentObject private var archive: ArchiveStore
    @Binding var selectedTab: ArchiveTab
    @Binding var selectedCategory: ArchiveCategory

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                siteHeader
                hero
                siteLinks
                categories
                resources
                latestItems
                Text("Version Production")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 26)
        }
        .background(Color.siteBackground)
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .navigationDestination(for: ArchiveItem.self) { item in
            NativeArchiveItemDetailView(item: item)
        }
        .navigationDestination(for: StaticArchivePage.self) { page in
            WebsitePageView(page: page)
        }
        .refreshable { await archive.load(force: true) }
    }

    private var siteHeader: some View {
        HStack(spacing: 10) {
            Image("SiteFavicon").resizable().scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text("BLUERYAI ARCHIVE")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                Text(".media")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("#stayblue")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.siteBlue)
        }
        .foregroundStyle(Color.siteText)
        .padding(.vertical, 4)
    }

    private var hero: some View {
        VStack(spacing: 17) {
            VStack(spacing: 9) {
                Text("The Blueryai Archive")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.42), Color(red: 0.77, green: 0.27, blue: 0.49), Color(red: 0.57, green: 0.36, blue: 0.95)], startPoint: .leading, endPoint: .trailing))
                Text("An on-going archive of blueryai’s content")
                    .font(.subheadline)
                    .foregroundStyle(Color.siteMuted)
                Text("Managed by altered_form · Inspired by FMHY")
                    .font(.caption2)
                    .foregroundStyle(Color.siteMuted.opacity(0.8))
            }
            .frame(maxWidth: .infinity)

            HomepagePhotoCarousel()
                .frame(width: 190, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12)))

            HStack(spacing: 7) {
                Text(archive.items.count.formatted())
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("archived items")
                    .font(.caption)
                    .foregroundStyle(Color.siteMuted)
            }
            if archive.isLoading && archive.items.isEmpty {
                ProgressView().tint(Color.siteBlue)
            }
            if let message = archive.errorMessage, archive.items.isEmpty {
                VStack(spacing: 8) {
                    Text(message).font(.caption).foregroundStyle(Color.siteMuted).multilineTextAlignment(.center)
                    Button("Try again") { Task { await archive.load(force: true) } }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.siteBlue)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var siteLinks: some View {
        VStack(alignment: .leading, spacing: 11) {
            SiteSectionHeading(title: "Around the community")
            LazyVGrid(columns: columns, spacing: 9) {
                ExternalSiteLink(title: "Announcements", detail: "Bluesky", url: "https://bsky.app/profile/blueryai.xyz")
                ExternalSiteLink(title: "Credits", detail: "People behind the archive", url: "https://blueryai.xyz/credits.html")
                ExternalSiteLink(title: "Resources", detail: "Community links", url: "https://blueryai.xyz/resources.html")
                ExternalSiteLink(title: "Contact", detail: "contact@blueryai.xyz", url: "mailto:contact@blueryai.xyz")
                ExternalSiteLink(title: "Discord", detail: "Join the BBG community", url: "https://discord.gg/tuFh5AjgJw")
                ExternalSiteLink(title: "Deleted BBG Wiki", detail: "Community archive", url: "https://blueryai.xyz/wiki/")
            }
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 11) {
            SiteSectionHeading(title: "What we have and organized")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(HomeCategory.all) { category in
                    Button {
                        selectedCategory = category.filter
                        selectedTab = .all
                    } label: {
                        HomeCategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    selectedCategory = .all
                    selectedTab = .all
                } label: {
                    HomeCategoryCard(category: .allContent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 11) {
            SiteSectionHeading(title: "Additional Resources")
            VStack(spacing: 10) {
                ForEach(HomeResource.all) { resource in
                    HomeResourceCard(resource: resource)
                }
            }
        }
    }

    private var latestItems: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .bottom) {
                SiteSectionHeading(title: "Recently added")
                Spacer()
                Button {
                    selectedCategory = .all
                    selectedTab = .all
                } label: {
                    HStack(spacing: 3) { Text("Show all"); Image(systemName: "chevron.right") }
                        .font(.caption)
                        .foregroundStyle(Color.siteBlue)
                }
                .buttonStyle(.plain)
            }
            if archive.isLoading && archive.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
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
}

private struct HomeCategory: Identifiable {
    let title: String
    let description: String
    let assetName: String
    let filter: ArchiveCategory
    var id: String { title }

    static let all: [HomeCategory] = [
        HomeCategory(title: "Blueryai VODs", description: "Full stream recordings saved or recovered from across the years (2021–2026).", assetName: "VodsIcon", filter: .vods),
        HomeCategory(title: "Blueryai Videos", description: "Community edits from deleted and private channels, alongside official uploads.", assetName: "VideosIcon", filter: .videos),
        HomeCategory(title: "Blueryai Clips", description: "Clips from streams and the ClipsofBlueRyai channel.", assetName: "ClipsIcon", filter: .clips),
        HomeCategory(title: "Blueryai Music", description: "Music and freestyles from BlueRyai Music.", assetName: "MusicIcon", filter: .music),
    ]

    static let allContent = HomeCategory(title: "Show All Blueryai Content", description: "Browse VODs, videos, clips and music together.", assetName: "AllContentIcon", filter: .all)
}

private struct HomeCategoryCard: View {
    let category: HomeCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(category.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .padding(7)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
            Text(category.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.siteText)
                .multilineTextAlignment(.leading)
            Text(category.description)
                .font(.caption2)
                .foregroundStyle(Color.siteMuted)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.siteCard, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.siteBorder))
    }
}

private struct HomeResource: Identifiable {
    struct Action: Identifiable {
        let title: String
        let url: String?
        var id: String { title }
    }

    let title: String
    let description: String
    let iconAssetName: String
    let actions: [Action]
    var id: String { title }

    private static let blueryaiLiveYears: [Action] = [
        Action(title: "2026", url: "https://mega.nz/folder/1UUAQY7Q#tFZyxjNuIQn6KMMCp40bDw"),
        Action(title: "2025 · 1", url: "https://mega.nz/folder/RQ0hiArI#77m98_GW9R3Uj72APb9CZg"),
        Action(title: "2025 · 2", url: "https://mega.nz/folder/e5RFRRZb#Ssz1FX8_GgtqQ1PrOGxWFA"),
        Action(title: "2025 · 3", url: "https://mega.nz/folder/Y6wVhBTC#doxpDQn1hiGllXY44nwLeg"),
        Action(title: "2025 · 4", url: "https://mega.nz/folder/gj43mYKD#bhNHNxVoWT6fh9_YdeM9xg"),
        Action(title: "2025 · 5", url: "https://mega.nz/folder/BAFGzQ4Y#fQtAfP9fQ7YhYnWZSZDMpQ"),
        Action(title: "2025 · 6", url: "https://mega.nz/folder/7kgSiRIC#2jQr36MokdK1I2YJoJoGnw"),
        Action(title: "2025 · 7", url: "https://mega.nz/folder/394g3YBJ#0Km6Tt0k5jYr_njYUiwwVQ"),
        Action(title: "2024 · 1", url: "https://mega.nz/folder/GChESRbD#vwaRBRjDf_hx94Q7OdTRUA"),
        Action(title: "2024 · 2", url: "https://mega.nz/folder/1jJWHZSR#OsKN10qfzSt6jEXHsuUR-g"),
        Action(title: "2024 · 3", url: "https://mega.nz/folder/zuw0hDJT#ViuZaCkgxDTANhGKpU8OaA"),
        Action(title: "2024 · 4", url: "https://mega.nz/folder/4ccWxR7S#DxIC0H36WiLd_Kj_siCLzA"),
        Action(title: "2024 · 5", url: "https://mega.nz/folder/U7wxyRKR#Mm6tPxe8nMOKzYiQ2NpNsw"),
        Action(title: "2022", url: "https://mega.nz/folder/B6oRVCiJ#a7-QO3WM8i1daioGuxER0w")
    ]

    private static let vodYearActions: [Action] = [
        Action(title: "2026 · GoFile", url: "https://gofile.io/d/WtB2C9GH"),
        Action(title: "2025 · Dropbox", url: "https://www.dropbox.com/scl/fo/k0tjpgw8lxjv65fl7hcs9/AE4FBqvd8U-dLF6nSf-IWBs?rlkey=l8132ms3i0w4b4pw42p3n58p9&st=gvrugkxw&dl=0"),
        Action(title: "2025 · GoFile", url: "https://gofile.io/d/ZsQ3u4fm"),
        Action(title: "2024", url: nil),
        Action(title: "2023 · GoFile", url: "https://gofile.io/d/Ig1ucdTn"),
        Action(title: "2022 · GoFile", url: "https://gofile.io/d/xV06GH4C"),
        Action(title: "2021", url: nil)
    ]

    static let all: [HomeResource] = [
        HomeResource(title: "All Bluniverse VODs", description: "The up-to-date Mega folder for BBG Bluniverse VODs.", iconAssetName: "MegaIcon", actions: [Action(title: "Browse Mega", url: "https://mega.nz/folder/4BA23JzA#CjeVRqa6-KeWDU-mMXUJdw")]),
        HomeResource(title: "VODS Archive", description: "A large archive containing most of BlueRyai’s VODs.", iconAssetName: "ArchiveIcon", actions: [Action(title: "Browse Archive.org", url: "https://archive.org/details/@kxngmxlesstreams/lists/2/blueryai-vods?sort=-publicdate")]),
        HomeResource(title: "BBG Pluh Videos", description: "121 videos from BBG Pluh.", iconAssetName: "GofileIcon", actions: [Action(title: "Browse GoFile", url: "https://gofile.io/d/YGeg2w")]),
        HomeResource(title: "Blueryai Chat Archive", description: "Download the ongoing chat collection or browse the files.", iconAssetName: "GofileIcon", actions: [Action(title: "Download ZIP", url: "https://file-na-phx-1.gofile.io/download/direct/74db5c32-49f7-4d5f-ad10-5df226de36ba/Chat.zip"), Action(title: "Browse", url: "https://gofile.io/d/vNu5Oo89")]),
        HomeResource(title: "Blueryai Live", description: "Archived livestream folders, organized by year.", iconAssetName: "MegaIcon", actions: blueryaiLiveYears),
        HomeResource(title: "Blueryai Live Plus", description: "Full Blueryai Live Plus folders hosted on GoFile.", iconAssetName: "GofileIcon", actions: [Action(title: "2025–2026", url: "https://gofile.io/d/Fi3FpJg5")]),
        HomeResource(title: "Full VOD Archives by Year", description: "Browse or download recovered VODs for each available year.", iconAssetName: "FullArchiveIcon", actions: vodYearActions)
    ]
}

private struct HomeResourceCard: View {
    let resource: HomeResource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(resource.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.siteText)
                    Text(resource.description).font(.caption2).foregroundStyle(Color.siteMuted)
                }
                Spacer(minLength: 0)
            }
            if !resource.actions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(resource.actions) { action in
                            HomeResourceAction(action: action)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.siteCard, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.siteBorder))
    }
}

private struct HomeResourceAction: View {
    @EnvironmentObject private var downloads: DownloadManager
    let action: HomeResource.Action

    private var source: ArchiveLink? {
        guard let url = action.url else { return nil }
        return ArchiveLink(name: action.title, urlString: url)
    }

    var body: some View {
        if let value = action.url, let url = URL(string: value) {
            if action.title.localizedCaseInsensitiveContains("download"), let source, source.canDownload {
                Button { downloads.download(source) } label: {
                    HStack(spacing: 5) {
                        if downloads.activeDownloads.contains(source.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.to.line")
                        }
                        Text(action.title)
                    }
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundStyle(Color.siteBlue)
                    .background(Color.siteBackground, in: Capsule())
                    .overlay(Capsule().stroke(Color.siteBorder))
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: url) {
                    Text(action.title)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(Color.siteBlue)
                        .background(Color.siteBackground, in: Capsule())
                        .overlay(Capsule().stroke(Color.siteBorder))
                }
            }
        } else {
            Text(action.title)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(Color.siteMuted)
                .background(Color.siteBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.siteBorder))
        }
    }
}

private struct SiteSectionHeading: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.siteMuted)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 7)
    }
}

private struct ExternalSiteLink: View {
    let title: String
    let detail: String
    let url: String

    @ViewBuilder
    var body: some View {
        if let page = StaticArchivePage.page(title: title, urlString: url) {
            NavigationLink(value: page) { label }
        } else if let link = URL(string: url) {
            Link(destination: link) { label }
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.siteBlue)
            Text(detail).font(.caption2).foregroundStyle(Color.siteMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.siteCard, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.siteBorder))
    }
}

private struct SiteImage: View {
    let url: String
    let contentMode: ContentMode

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Color.siteCard)
                    .overlay(Image(systemName: "photo").font(.caption).foregroundStyle(Color.siteMuted))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct HomepagePhotoCarousel: View {
    private let photos = [
        "https://blueryai.xyz/ImagesOfRyai/NewHouse3.jpg",
        "https://blueryai.xyz/ImagesOfRyai/Japan1.jpg",
        "https://blueryai.xyz/ImagesOfRyai/NewHouse12.jpg",
        "https://blueryai.xyz/ImagesOfRyai/Outside8.jpg",
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / 3) % photos.count
            SiteImage(url: photos[index], contentMode: .fill)
                .animation(.easeInOut(duration: 0.4), value: index)
        }
    }
}

extension Color {
    static let siteBackground = Color(red: 0.051, green: 0.067, blue: 0.090)
    static let siteCard = Color(red: 0.086, green: 0.106, blue: 0.133)
    static let siteBorder = Color(red: 0.129, green: 0.153, blue: 0.184)
    static let siteText = Color(red: 0.788, green: 0.820, blue: 0.851)
    static let siteMuted = Color(red: 0.545, green: 0.580, blue: 0.620)
    static let siteBlue = Color(red: 0.345, green: 0.650, blue: 1)
}
