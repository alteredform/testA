import SwiftUI
import WebKit
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    let backup: Backup

    func makeUIView(context: Context) -> UIView {
        guard let url = backup.playbackURL else {
            return makePlaceholder("Invalid source URL")
        }

        // YouTube / embeddable → WKWebView
        if backup.isYouTube {
            let web = WKWebView()
            web.isOpaque = false
            web.backgroundColor = .black
            web.scrollView.isScrollEnabled = false
            web.allowsInlineMediaPlayback = true
            web.mediaTypeRequiresUserAction = false
            web.load(URLRequest(url: url))
            return web
        }

        // Direct media → AVPlayer
        if backup.isDirectMedia {
            let player = AVPlayer(url: url)
            let vc = AVPlayerViewController()
            vc.player = player
            vc.showsPlaybackControls = true
            vc.view.backgroundColor = .black
            player.play()
            return vc.view
        }

        // Fallback — load in WKWebView (e.g. third-party embed pages)
        let web = WKWebView()
        web.isOpaque = false
        web.backgroundColor = .black
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func makePlaceholder(_ message: String) -> UIView {
        let v = UILabel()
        v.text = message
        v.textColor = .secondaryLabel
        v.textAlignment = .center
        v.backgroundColor = .black
        return v
    }
}