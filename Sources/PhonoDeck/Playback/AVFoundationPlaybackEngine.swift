import AVFoundation
import Foundation

@MainActor
final class AVFoundationPlaybackEngine: PlaybackEngine, PlaybackEngineEventEmitting {
    let kind: PlaybackEngineKind = .nativeAV
    weak var eventObserver: PlaybackEngineEventObserving?

    private(set) var loadedItem: PlaybackQueueItem?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSKeyValueObservation?

    var elapsedTime: TimeInterval {
        guard let player else { return 0 }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(seconds, 0) : 0
    }

    var duration: TimeInterval? {
        guard let duration = playerItem?.duration.seconds, duration.isFinite, duration > 0 else { return loadedItem?.track.durationSeconds }
        return duration
    }

    var isPlaying: Bool { player?.timeControlStatus == .playing }

    func load(_ item: PlaybackQueueItem) async throws {
        cleanupObservers()
        guard item.routeDecision.engine == .nativeAV else {
            throw PlaybackFailure.engineFailed(reason: "\(item.source.descriptor.displayName) cannot load on nativeAV.")
        }
        let url: URL
        switch item.requestedPlan {
        case .nativeStream(let streamURL):
            guard streamURL.scheme?.isEmpty == false else { throw PlaybackFailure.invalidMediaURL(streamURL) }
            url = streamURL
        case .localFile(let fileURL):
            guard fileURL.isFileURL else { throw PlaybackFailure.invalidMediaURL(fileURL) }
            url = fileURL
        default:
            throw PlaybackFailure.engineFailed(reason: "Only native stream and local file plans can load in the native engine.")
        }

        let asset = AVURLAsset(url: url)
        let newItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: newItem)
        loadedItem = item
        playerItem = newItem
        player = newPlayer
        installObservers(for: newItem, player: newPlayer)
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        cleanupObservers()
        loadedItem = nil
        player = nil
        playerItem = nil
    }

    func seek(to seconds: TimeInterval) {
        let clampedSeconds = max(seconds, 0)
        player?.seek(to: CMTime(seconds: clampedSeconds, preferredTimescale: 600))
    }

    private func installObservers(for item: AVPlayerItem, player: AVPlayer) {
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playerItem === item, let loadedItem = self.loadedItem else { return }
                self.eventObserver?.playbackEngineDidFinishItem(loadedItem)
            }
        }

        failedObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else { return }
            Task { @MainActor in
                guard let self, self.playerItem === observedItem else { return }
                self.eventObserver?.playbackEngineDidFail(.engineFailed(reason: observedItem.error?.localizedDescription ?? "AVFoundation item failed."))
            }
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 2), queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.player === player else { return }
                self.eventObserver?.playbackEngineDidUpdateTime(elapsed: self.elapsedTime, duration: self.duration)
            }
        }
    }

    private func cleanupObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        failedObserver?.invalidate()
        failedObserver = nil
    }
}