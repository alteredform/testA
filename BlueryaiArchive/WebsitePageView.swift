import SwiftUI
import UIKit
import WebKit

struct StaticArchivePage: Hashable, Identifiable {
    let title: String
    let url: URL

    var id: URL { url }

    static func page(title: String, urlString: String) -> StaticArchivePage? {
        guard let url = URL(string: urlString), url.host == "blueryai.xyz" else { return nil }
        let path = url.path.lowercased()
        guard path.hasSuffix(".html") || path == "/wiki/" || path == "/wiki" else { return nil }
        return StaticArchivePage(title: title, url: url)
    }
}

struct WebsitePageView: View {
    let page: StaticArchivePage

    var body: some View {
        WebsitePageWebView(url: page.url)
            .id(page.url)
            .background(Color.siteBackground)
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebsitePageWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
