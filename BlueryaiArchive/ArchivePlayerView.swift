import AVKit
import SwiftUI
import WebKit

struct ArchivePlayerView: View {
    let source: ArchiveLink
    @Binding var playbackTime: Double

    var body: some View {
        Group {
            if source.isDirectMedia {
                DirectArchivePlayer(url: source.url, playbackTime: $playbackTime)
                    .id(source.id)
            } else {
                EmbeddedArchivePlayer(url: source.playbackURL, youtubeId: source.youtubeId, playbackTime: $playbackTime)
                    .id(source.id)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
    }
}

private struct DirectArchivePlayer: View {
    let url: URL
    @Binding var playbackTime: Double
    @State private var player: AVPlayer
    @State private var observer: Any?

    init(url: URL, playbackTime: Binding<Double>) {
        self.url = url
        self._playbackTime = playbackTime
        self._player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.play()
                observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
                    if time.seconds.isFinite { playbackTime = time.seconds }
                }
            }
            .onDisappear {
                player.pause()
                if let observer { player.removeTimeObserver(observer) }
                observer = nil
            }
    }
}

private struct EmbeddedArchivePlayer: UIViewRepresentable {
    let url: URL
    let youtubeId: String?
    @Binding var playbackTime: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(playbackTime: $playbackTime)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "archivePlaybackTime")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        context.coordinator.load(in: webView, url: url, youtubeId: youtubeId)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.playbackTime = $playbackTime
        context.coordinator.load(in: webView, url: url, youtubeId: youtubeId)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var playbackTime: Binding<Double>
        private var loadedKey: String?

        init(playbackTime: Binding<Double>) {
            self.playbackTime = playbackTime
        }

        func load(in webView: WKWebView, url: URL, youtubeId: String?) {
            let key = youtubeId.map { "youtube:\($0)" } ?? url.absoluteString
            guard key != loadedKey else { return }
            loadedKey = key
            if let youtubeId {
                let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
                let safeID = String(youtubeId.unicodeScalars.filter { safeCharacters.contains($0) })
                let html = """
                <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><style>*{box-sizing:border-box}html,body,#player{margin:0;width:100%;height:100%;overflow:hidden;background:#000}</style></head><body><div id="player"></div><script src="https://www.youtube.com/iframe_api"></script><script>
                let player;function onYouTubeIframeAPIReady(){player=new YT.Player('player',{videoId:'\(safeID)',playerVars:{playsinline:1,autoplay:0,rel:0,enablejsapi:1,origin:'https://blueryai.xyz'},events:{onReady:function(){setInterval(function(){try{window.webkit.messageHandlers.archivePlaybackTime.postMessage(player.getCurrentTime()||0)}catch(e){}},500)}}})}
                </script></body></html>
                """
                webView.loadHTMLString(html, baseURL: URL(string: "https://blueryai.xyz/"))
            } else if url.host?.lowercased().contains("twitch.tv") == true {
                let escapedURL = url.absoluteString
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                let html = """
                <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><style>html,body,iframe{margin:0;width:100%;height:100%;border:0;overflow:hidden;background:#000}</style></head><body><iframe src="\(escapedURL)" allow="autoplay; fullscreen" allowfullscreen></iframe></body></html>
                """
                webView.loadHTMLString(html, baseURL: URL(string: "https://blueryai.xyz/"))
            } else {
                webView.load(URLRequest(url: url))
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "archivePlaybackTime", let time = message.body as? Double, time.isFinite else { return }
            playbackTime.wrappedValue = time
        }
    }
}
