import AVFoundation
import Foundation
import SwiftUI

struct PlaybackSeekRequest: Identifiable, Equatable {
    let id = UUID()
    let seconds: Double
}

@MainActor
final class ArchivePlaybackManager: ObservableObject {
    static let shared = ArchivePlaybackManager()

    @Published var playbackTime: Double = 0
    @Published var seekRequest: PlaybackSeekRequest?
    @Published private(set) var currentSourceID: String?
    @Published private(set) var failedSourceID: String?
    @Published private(set) var duration: Double = 0
    @Published private(set) var isPlaying = false
    let player = AVPlayer()

    private var timeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?

    private init() {
        player.automaticallyWaitsToMinimizeStalling = true
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.4, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard time.seconds.isFinite else { return }
            Task { @MainActor in
                guard let self else { return }
                self.playbackTime = time.seconds
                let currentDuration = self.player.currentItem?.duration.seconds ?? 0
                self.duration = currentDuration.isFinite ? max(0, currentDuration) : 0
                self.isPlaying = self.player.rate > 0
            }
        }
    }

    func prepare(_ source: ArchiveLink) {
        activateAudioSession()
        guard currentSourceID != source.id else { return }
        currentSourceID = source.id
        playbackTime = 0
        duration = 0
        isPlaying = false
        seekRequest = nil
        failedSourceID = nil
        itemStatusObservation = nil

        if source.isDirectMedia || source.isAudioMedia {
            let sourceID = source.id
            let item = AVPlayerItem(url: source.playbackURL)
            itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .failed || item.status == .readyToPlay else { return }
                let duration = item.duration.seconds
                Task { @MainActor [weak self] in
                    guard self?.currentSourceID == sourceID else { return }
                    if item.status == .failed {
                        self?.failedSourceID = sourceID
                    } else if duration.isFinite {
                        self?.duration = max(0, duration)
                    }
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
        } else {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let target = max(0, seconds)
        playbackTime = target
        if player.currentItem != nil, failedSourceID != currentSourceID {
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            seekRequest = PlaybackSeekRequest(seconds: target)
        }
    }

    func togglePlayback() {
        if player.rate > 0 {
            player.pause()
            isPlaying = false
        } else if player.currentItem != nil {
            activateAudioSession()
            player.play()
            isPlaying = true
        }
    }

    private func activateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
        } catch {
            // Playback remains available even if the audio session cannot be changed.
        }
    }

}
