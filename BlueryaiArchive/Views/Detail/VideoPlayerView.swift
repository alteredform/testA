import SwiftUI
import WebKit
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    let backup: Backup

    func makeUIView(context: Context) -> UIView {
        guard let url = backup.playbackURL else { return placeholder("Invalid source URL") }

        if backup.isYouTube {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            let web = WKWebView(frame: .zero, configuration: config)
            web.isOpaque = false
            web.backgroundColor = .black
            web.scrollView.isScrollEnabled = false
            web.load(URLRequest(url: url))
            return web
        }

        if backup.isDirectMedia {
            let player = AVPlayer(url: url)
            let vc = AVPlayerViewController()
            vc.player = player
            vc.showsPlaybackControls = true
            vc.view.backgroundColor = .black
            player.play()
            return vc.view
        }

        let web = WKWebView()
        web.isOpaque = false
        web.backgroundColor = .black
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func placeholder(_ message: String) -> UIView {
        let v = UILabel()
        v.text = message
        v.textColor = .secondaryLabel
        v.textAlignment = .center
        v.backgroundColor = .black
        return v
    }
}