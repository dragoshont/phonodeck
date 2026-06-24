import AVFoundation
import Foundation

struct PlaybackQueueItem: Identifiable, Equatable {
    let id: UUID
    let track: MusicTrack
    let routeDecision: PlaybackRouteDecision

    var source: MediaSourceKind { track.source }
    var requestedPlan: PlaybackPlan { routeDecision.plan }

    init(id: UUID = UUID(), track: MusicTrack, routeDecision: PlaybackRouteDecision) {
        self.id = id
        self.track = track
        self.routeDecision = routeDecision
    }
}

enum PlaybackRepeatMode: String, Codable, Equatable {
    case off
    case one
    case all
}

struct PlaybackQueueSnapshot: Equatable {
    let items: [PlaybackQueueItem]
    let currentIndex: Int?
    let repeatMode: PlaybackRepeatMode
    let shuffleEnabled: Bool

    static let empty = PlaybackQueueSnapshot(items: [], currentIndex: nil, repeatMode: .off, shuffleEnabled: false)

    var currentItem: PlaybackQueueItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    func replacing(items newItems: [PlaybackQueueItem], currentIndex: Int?) -> PlaybackQueueSnapshot {
        PlaybackQueueSnapshot(items: newItems, currentIndex: currentIndex, repeatMode: repeatMode, shuffleEnabled: shuffleEnabled)
    }
}

enum PlaybackSessionState: Equatable {
    case idle
    case loading(PlaybackQueueItem)
    case playing(PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?)
    case paused(PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?)
    case ended(PlaybackQueueItem)
    case blocked(PlaybackBlockedState)
    case failed(PlaybackFailure)
}

@MainActor
protocol PlaybackEngine: AnyObject {
    var kind: PlaybackEngineKind { get }
    var loadedItem: PlaybackQueueItem? { get }
    var elapsedTime: TimeInterval { get }
    var duration: TimeInterval? { get }
    var isPlaying: Bool { get }

    func load(_ item: PlaybackQueueItem) async throws
    func play()
    func pause()
    func stop()
    func seek(to seconds: TimeInterval)
}

@MainActor
protocol PlaybackEngineEventObserving: AnyObject {
    func playbackEngineDidUpdateTime(elapsed: TimeInterval, duration: TimeInterval?)
    func playbackEngineDidFinishItem(_ item: PlaybackQueueItem)
    func playbackEngineDidFail(_ failure: PlaybackFailure)
}

@MainActor
protocol PlaybackEngineEventEmitting: AnyObject {
    var eventObserver: PlaybackEngineEventObserving? { get set }
}

@MainActor
final class ImmediatePlaybackEngine: PlaybackEngine {
    let kind: PlaybackEngineKind
    private let loadFailure: PlaybackFailure?
    private(set) var loadedItem: PlaybackQueueItem?
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var duration: TimeInterval?
    private(set) var isPlaying = false

    init(kind: PlaybackEngineKind = .nativeAV, loadFailure: PlaybackFailure? = nil) {
        self.kind = kind
        self.loadFailure = loadFailure
    }

    func load(_ item: PlaybackQueueItem) async throws {
        if let loadFailure { throw loadFailure }
        guard item.routeDecision.engine == kind else {
            throw PlaybackFailure.engineFailed(reason: "\(item.source.descriptor.displayName) cannot load on \(kind.rawValue).")
        }
        switch item.requestedPlan {
        case .nativeStream(let url):
            guard url.scheme?.isEmpty == false else { throw PlaybackFailure.invalidMediaURL(url) }
        case .localFile(let url):
            guard url.isFileURL else { throw PlaybackFailure.invalidMediaURL(url) }
        default:
            throw PlaybackFailure.engineFailed(reason: "Only native stream and local file plans can load in the native engine.")
        }
        loadedItem = item
        elapsedTime = 0
        duration = item.track.durationSeconds
        isPlaying = false
    }

    func play() {
        guard loadedItem != nil else { return }
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        loadedItem = nil
        elapsedTime = 0
        duration = nil
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        elapsedTime = max(seconds, 0)
    }
}

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