import SwiftUI
import WebKit

enum Site {
    static let home = URL(string: "https://blueryai.xyz/")!
}

struct SiteSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let url: URL

    static let all: [SiteSection] = [
        SiteSection(title: "Home", icon: "house", url: URL(string: "https://blueryai.xyz/")!),
        SiteSection(title: "VODs", icon: "play.rectangle", url: URL(string: "https://blueryai.xyz/all?type=vods")!),
        SiteSection(title: "Videos", icon: "film", url: URL(string: "https://blueryai.xyz/all?type=videos")!),
        SiteSection(title: "Clips", icon: "scissors", url: URL(string: "https://blueryai.xyz/all?type=clips")!),
        SiteSection(title: "Music", icon: "music.note", url: URL(string: "https://blueryai.xyz/all?type=music")!),
        SiteSection(title: "All Content", icon: "square.grid.2x2", url: URL(string: "https://blueryai.xyz/all")!),
        SiteSection(title: "Resources", icon: "books.vertical", url: URL(string: "https://blueryai.xyz/resources.html")!),
        SiteSection(title: "Credits", icon: "person.2", url: URL(string: "https://blueryai.xyz/credits.html")!),
        SiteSection(title: "Deleted BBG Wiki", icon: "book", url: URL(string: "https://blueryai.xyz/wiki/")!)
    ]
}

/// One browser tab. Owns its WKWebView so switching tabs keeps page state.
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let webView: WKWebView

    @Published var title: String = "New Tab"
    @Published var url: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0

    /// Called when a page asks to open a new window (target=_blank, window.open).
    var onOpenNewTab: ((URLRequest) -> Void)?

    private var observers: [NSKeyValueObservation] = []

    init(url: URL?) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        // Present as mobile Safari so sites (file hosts etc.) serve their normal mobile pages.
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        observe()
        if let url { load(url) }
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    @objc private func handleRefresh() {
        webView.reload()
    }

    private func observe() {
        observers.append(webView.observe(\.title) { [weak self] wv, _ in
            let t = wv.title
            let host = wv.url?.host
            DispatchQueue.main.async {
                if let t, !t.isEmpty { self?.title = t } else { self?.title = host ?? "New Tab" }
            }
        })
        observers.append(webView.observe(\.url) { [weak self] wv, _ in
            let u = wv.url
            DispatchQueue.main.async { self?.url = u }
        })
        observers.append(webView.observe(\.canGoBack) { [weak self] wv, _ in
            let v = wv.canGoBack
            DispatchQueue.main.async { self?.canGoBack = v }
        })
        observers.append(webView.observe(\.canGoForward) { [weak self] wv, _ in
            let v = wv.canGoForward
            DispatchQueue.main.async { self?.canGoForward = v }
        })
        observers.append(webView.observe(\.isLoading) { [weak self] wv, _ in
            let v = wv.isLoading
            DispatchQueue.main.async { self?.isLoading = v }
        })
        observers.append(webView.observe(\.estimatedProgress) { [weak self] wv, _ in
            let v = wv.estimatedProgress
            DispatchQueue.main.async { self?.progress = v }
        })
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           !["http", "https", "about", "blob", "data", "file"].contains(scheme) {
            // mailto:, tel:, app links, etc. are handed to the system.
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame else {
            decisionHandler(.allow)
            return
        }
        if let http = navigationResponse.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition"),
           disposition.lowercased().hasPrefix("attachment") {
            decisionHandler(.download)
            return
        }
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        DownloadManager.shared.register(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        DownloadManager.shared.register(download)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    private func handleFailure(_ error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        let ns = error as NSError
        // Ignore cancellations and "frame load interrupted" (which happens when a load turns into a download).
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }

        let message = ns.localizedDescription
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body{font-family:-apple-system;padding:48px 24px;text-align:center;color:#888}
        h2{color:#666}</style></head>
        <body><h2>Can't load page</h2><p>\(message)</p><p>Pull down to try again.</p></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Links that want a new window open in a new in-app tab.
        if navigationAction.targetFrame == nil {
            onOpenNewTab?(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, fallback: completionHandler)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, fallback: { completionHandler(false) })
    }

    private func present(_ alert: UIAlertController, fallback: () -> Void) {
        if let vc = UIApplication.shared.topViewController {
            vc.present(alert, animated: true)
        } else {
            fallback()
        }
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

/// Holds all open tabs.
final class TabStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?

    init() {
        openTab(url: Site.home)
    }

    var selected: BrowserTab? {
        tabs.first { $0.id == selectedID } ?? tabs.first
    }

    @discardableResult
    func openTab(url: URL?) -> BrowserTab {
        let tab = BrowserTab(url: url)
        tab.onOpenNewTab = { [weak self] request in
            self?.openTab(request: request)
        }
        tabs.append(tab)
        selectedID = tab.id
        return tab
    }

    func openTab(request: URLRequest) {
        let tab = openTab(url: nil)
        tab.webView.load(request)
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.webView.stopLoading()
        tabs.remove(at: index)
        if tabs.isEmpty {
            openTab(url: Site.home)
        } else if selectedID == tab.id {
            selectedID = tabs[min(index, tabs.count - 1)].id
        }
    }
}
