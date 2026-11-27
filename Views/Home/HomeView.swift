import SwiftUI

enum WebPage: String, Identifiable {
    case credits, resources, wiki
    var id: String { rawValue }

    var title: String {
        switch self {
        case .credits:   return "Credits"
        case .resources: return "Resources"
        case .wiki:      return "Deleted BBG Wiki"
        }
    }

    var url: URL {
        switch self {
        case .credits:   return URL(string: "https://blueryai.xyz/credits.html")!
        case .resources: return URL(string: "https://blueryai.xyz/resources.html")!
        case .wiki:      return URL(string: "https://blueryai.xyz/wiki/")!
        }
    }
}

struct HomeView: View {
    @State private var webPage: WebPage?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Hero
                VStack(spacing: 12) {
                    Text("The Blueryai Archive")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#ff6b6b"), Color(hex: "#8b5cf6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("An on-going archive of blueryai's content")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#8b949e"))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)
                .padding(.horizontal)

                // Quick links
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        LinkButton(title: "Announcements", icon: "megaphone",
                                   url: "https://bsky.app/profile/blueryai.xyz")
                        LinkButton(title: "Credits", icon: "person.2",
                                   action: { webPage = .credits })
                        LinkButton(title: "Resources", icon: "book",
                                   action: { webPage = .resources })
                    }
                    HStack(spacing: 12) {
                        LinkButton(title: "Discord", icon: "bubble.left.and.bubble.right",
                                   url: "https://discord.gg/tuFh5AjgJw")
                        LinkButton(title: "Wiki", icon: "globe",
                                   action: { webPage = .wiki })
                        LinkButton(title: "Contact", icon: "envelope",
                                   url: "mailto:contact@blueryai.xyz")
                    }
                }
                .padding(.horizontal)

                // Browse grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("Browse")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#c9d1d9"))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NavigationLink(value: ItemType.vods) {
                            CategoryCard(title: "VODs", icon: "play.rectangle",
                                         color: Color(hex: "#58a6ff"))
                        }
                        NavigationLink(value: ItemType.videos) {
                            CategoryCard(title: "Videos", icon: "film",
                                         color: Color(hex: "#a371f7"))
                        }
                        NavigationLink(value: ItemType.clips) {
                            CategoryCard(title: "Clips", icon: "scissors",
                                         color: Color(hex: "#ff6b6b"))
                        }
                        NavigationLink(value: ItemType.music) {
                            CategoryCard(title: "Music", icon: "music.note",
                                         color: Color(hex: "#2ea043"))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .background(Color(hex: "#0d1117").ignoresSafeArea())
        .navigationDestination(for: ItemType.self) { type in
            BrowseView(type: type)
        }
        .sheet(item: $webPage) { page in
            NavigationStack {
                WebPageView(url: page.url)
                    .navigationTitle(page.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { webPage = nil }
                        }
                    }
            }
        }
    }
}

// MARK: - Small components

struct LinkButton: View {
    let title: String
    let icon: String
    var url: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                Link(destination: u) { label }
            } else {
                Button { action?() } label: { label }
            }
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#161b22"))
        .foregroundColor(Color(hex: "#58a6ff"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#30363d"), lineWidth: 1)
        )
    }
}

struct CategoryCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color(hex: "#c9d1d9"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(hex: "#161b22"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#21262d"), lineWidth: 1)
        )
    }
}