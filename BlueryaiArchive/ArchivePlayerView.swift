import AVKit
import SwiftUI
import WebKit

struct ArchivePlayerView: View {
    @EnvironmentObject private var playback: ArchivePlaybackManager
    let source: ArchiveLink
    @Binding var playbackTime: Double

    var body: some View {
        Group {
            if source.isAudioMedia {
                ArchiveAudioPlayer(source: source)
                    .id(source.id)
            } else if source.isDirectMedia {
                DirectArchivePlayer(playback: playback)
                    .id(source.id)
            } else {
                EmbeddedArchivePlayer(url: source.playbackURL, youtubeId: source.youtubeId, playbackTime: $playbackTime, seekRequest: $playback.seekRequest)
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

private struct ArchiveAudioPlayer: View {
    @EnvironmentObject private var playback: ArchivePlaybackManager
    let source: ArchiveLink

    private var sliderValue: Binding<Double> {
        Binding(
            get: { min(playback.playbackTime, max(playback.duration, 1)) },
            set: { playback.seek(to: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image("MusicIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    Text("Blueryai Archive audio").font(.caption2).foregroundStyle(Color.siteMuted)
                }
                Spacer(minLength: 0)
            }
            Slider(value: sliderValue, in: 0...max(playback.duration, 1))
                .tint(Color.siteBlue)
            HStack {
                Text(clock(playback.playbackTime))
                Spacer()
                Text(playback.duration > 0 ? clock(playback.duration) : "--:--")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.siteMuted)
            HStack(spacing: 30) {
                Button { playback.seek(to: max(0, playback.playbackTime - 15)) } label: {
                    Image(systemName: "gobackward.15").font(.title3)
                }
                .accessibilityLabel("Back 15 seconds")
                Button { playback.togglePlayback() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .background(Color.siteBlue, in: Circle())
                        .foregroundStyle(Color.black)
                }
                .accessibilityLabel(playback.isPlaying ? "Pause audio" : "Play audio")
                Button { playback.seek(to: min(playback.duration, playback.playbackTime + 15)) } label: {
                    Image(systemName: "goforward.15").font(.title3)
                }
                .accessibilityLabel("Forward 15 seconds")
            }
            .foregroundStyle(Color.siteText)
        }
        .padding(15)
        .background(Color.siteCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.siteBorder))
    }

    private func clock(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, remainder) : String(format: "%d:%02d", minutes, remainder)
    }
}

private struct DirectArchivePlayer: UIViewControllerRepresentable {
    let playback: ArchivePlaybackManager

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = playback.player
        controller.videoGravity = .resizeAspect
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== playback.player { controller.player = playback.player }
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
    }
}

private struct EmbeddedArchivePlayer: UIViewRepresentable {
    let url: URL
    let youtubeId: String?
    @Binding var playbackTime: Double
    @Binding var seekRequest: PlaybackSeekRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(playbackTime: $playbackTime, seekRequest: $seekRequest)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "archivePlaybackTime")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
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
        context.coordinator.seekRequest = $seekRequest
        context.coordinator.load(in: webView, url: url, youtubeId: youtubeId)
        context.coordinator.applyPendingSeek(in: webView, youtubeId: youtubeId)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var playbackTime: Binding<Double>
        var seekRequest: Binding<PlaybackSeekRequest?>
        private var loadedKey: String?
        private var lastSeekRequestID: UUID?

        init(playbackTime: Binding<Double>, seekRequest: Binding<PlaybackSeekRequest?>) {
            self.playbackTime = playbackTime
            self.seekRequest = seekRequest
        }

        func applyPendingSeek(in webView: WKWebView, youtubeId: String?) {
            guard let request = seekRequest.wrappedValue,
                  request.id != lastSeekRequestID,
                  youtubeId != nil else { return }
            lastSeekRequestID = request.id
            let target = String(format: "%.3f", request.seconds)
            webView.evaluateJavaScript("if(window.archivePlayer&&window.archivePlayer.seekTo){window.archivePlayer.seekTo(\(target),true)}", completionHandler: nil)
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
                function onYouTubeIframeAPIReady(){window.archivePlayer=new YT.Player('player',{videoId:'\(safeID)',playerVars:{playsinline:1,autoplay:0,rel:0,enablejsapi:1,origin:'https://blueryai.xyz'},events:{onReady:function(){window.archivePlayer.getIframe().setAttribute('allow','accelerometer; autoplay; clipboard-write; encrypted-media; picture-in-picture; fullscreen');setInterval(function(){try{window.webkit.messageHandlers.archivePlaybackTime.postMessage(window.archivePlayer.getCurrentTime()||0)}catch(e){}},500)}}})}
                </script></body></html>
                """
                webView.loadHTMLString(html, baseURL: URL(string: "https://blueryai.xyz/"))
            } else if url.host?.lowercased().contains("twitch.tv") == true {
                let escapedURL = url.absoluteString
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                let html = """
                <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><style>html,body,iframe{margin:0;width:100%;height:100%;border:0;overflow:hidden;background:#000}</style></head><body><iframe src="\(escapedURL)" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe></body></html>
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
