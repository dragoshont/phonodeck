import OSLog
import SwiftUI
import WebKit

enum YouTubeEmbeddedPlayerState: Equatable {
    case idle
    case ready
    case buffering
    case playing
    case paused
    case ended
    case failed(String)

    var title: String {
        switch self {
        case .idle: "Idle"
        case .ready: "Ready"
        case .buffering: "Buffering"
        case .playing: "Playing"
        case .paused: "Paused"
        case .ended: "Ended"
        case .failed: "Failed"
        }
    }

    var acceptsCommands: Bool {
        switch self {
        case .ready, .buffering, .playing, .paused, .ended:
            true
        case .idle, .failed:
            false
        }
    }
}

@MainActor
final class YouTubeMusicWebPlayerController: NSObject, ObservableObject {
    @Published private(set) var title: String = "YouTube Player"
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var playerState: YouTubeEmbeddedPlayerState = .idle
    @Published private(set) var volume: Double = 100
    @Published private(set) var isMuted = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private weak var webView: WKWebView?
    private let appOrigin = "https://ro.hont.phonodeck"
    private(set) var currentVideoID: String?
    private var pendingHTML: String?

    func attach(_ webView: WKWebView) {
        guard self.webView !== webView else { return }
        self.webView = webView
        AppLog.player.info("WKWebView attached to YouTube player controller; had pending html=\((self.pendingHTML != nil).description, privacy: .public)")
        if let pendingHTML {
            webView.loadHTMLString(pendingHTML, baseURL: URL(string: appOrigin)!)
            self.pendingHTML = nil
            refreshState()
            AppLog.player.info("Loaded pending YouTube player HTML after WebView attach; video=\(self.currentVideoID ?? "none", privacy: .public)")
        }
    }

    func load(video: YouTubeVideoSearchResult, autoplay: Bool = false) {
        currentVideoID = video.id
        title = video.title
        playerState = .idle
        AppLog.player.info("YouTube player load requested; video=\(video.id, privacy: .public), title=\(video.title, privacy: .private), autoplay=\(autoplay.description, privacy: .public)")
        let html = playerHTML(videoID: video.id, autoplay: autoplay)
        if let webView {
            webView.loadHTMLString(html, baseURL: URL(string: appOrigin)!)
            AppLog.player.info("YouTube player HTML load started; video=\(video.id, privacy: .public)")
        } else {
            pendingHTML = html
            AppLog.player.info("YouTube player load deferred because WebView is not attached; video=\(video.id, privacy: .public)")
        }
        refreshState()
    }

    func stopAndReset() {
        AppLog.player.info("YouTube player stop/reset requested; video=\(self.currentVideoID ?? "none", privacy: .public), state=\(self.playerState.title, privacy: .public)")
        if playerState.acceptsCommands {
            evaluatePlayerCommand("stopVideo")
        }
        pendingHTML = nil
        currentVideoID = nil
        currentTime = 0
        duration = 0
        playerState = .idle
    }

    func play() {
        guard playerState.acceptsCommands else {
            AppLog.player.debug("Ignoring play command because player does not accept commands; state=\(self.playerState.title, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
            return
        }
        AppLog.player.info("YouTube player play command; video=\(self.currentVideoID ?? "none", privacy: .public)")
        evaluatePlayerCommand("playVideo")
    }

    func pause() {
        guard playerState.acceptsCommands else {
            AppLog.player.debug("Ignoring pause command because player does not accept commands; state=\(self.playerState.title, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
            return
        }
        AppLog.player.info("YouTube player pause command; video=\(self.currentVideoID ?? "none", privacy: .public)")
        evaluatePlayerCommand("pauseVideo")
    }

    func togglePlayPause() {
        if playerState == .playing {
            pause()
        } else {
            play()
        }
    }

    func toggleMute() {
        guard playerState.acceptsCommands else {
            AppLog.player.debug("Ignoring mute toggle because player does not accept commands; state=\(self.playerState.title, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
            return
        }
        AppLog.player.info("YouTube player mute toggle; currently muted=\(self.isMuted.description, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
        if isMuted {
            evaluatePlayerCommand("unMute")
        } else {
            evaluatePlayerCommand("mute")
        }
    }

    func setVolume(_ volume: Double) {
        guard playerState.acceptsCommands else {
            AppLog.player.debug("Ignoring volume command because player does not accept commands; state=\(self.playerState.title, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
            return
        }
        let clampedVolume = min(max(volume, 0), 100)
        self.volume = clampedVolume
        AppLog.player.debug("YouTube player set volume; volume=\(Int(clampedVolume), privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
        webView?.evaluateJavaScript("if (window.phonoDeckPlayer) { window.phonoDeckPlayer.setVolume(\(Int(clampedVolume))); window.phonoDeckSyncVolume(); }") { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.playerState = .failed(error.localizedDescription)
                AppLog.player.error("YouTube player set volume failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func goBack() {
        webView?.goBack()
        refreshState()
    }

    func goForward() {
        webView?.goForward()
        refreshState()
    }

    func reload() {
        AppLog.player.info("YouTube player WebView reload requested; video=\(self.currentVideoID ?? "none", privacy: .public)")
        webView?.reload()
    }

    func refreshState() {
        title = webView?.title?.isEmpty == false ? webView?.title ?? title : title
        isLoading = webView?.isLoading ?? false
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }

        func handlePlayerMessage(_ message: [String: Any]) {
                guard let event = message["event"] as? String else { return }
                switch event {
                case "ready":
                        playerState = .ready
                AppLog.player.info("YouTube IFrame ready; video=\(self.currentVideoID ?? "none", privacy: .public)")
                case "state":
                        let value = message["value"] as? Int ?? -1
                        playerState = switch value {
                        case -1: .ready
                        case 0: .ended
                        case 1: .playing
                        case 2: .paused
                        case 3: .buffering
                        default: playerState
                        }
                AppLog.player.info("YouTube IFrame state changed; raw=\(value, privacy: .public), state=\(self.playerState.title, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
                case "error":
                        let value = message["value"] as? Int ?? 0
                        playerState = .failed("YouTube player error \(value)")
                AppLog.player.error("YouTube IFrame error; code=\(value, privacy: .public), video=\(self.currentVideoID ?? "none", privacy: .public)")
                case "volume":
                    volume = (message["value"] as? Double) ?? Double(message["value"] as? Int ?? Int(volume))
                case "muted":
                    isMuted = (message["value"] as? Int ?? 0) == 1
                case "time":
                    currentTime = (message["value"] as? Double) ?? Double(message["value"] as? Int ?? 0)
                case "duration":
                    duration = (message["value"] as? Double) ?? Double(message["value"] as? Int ?? 0)
                default:
                        break
                }
        }

        private func evaluatePlayerCommand(_ command: String) {
            AppLog.player.debug("Evaluating YouTube player command \(command, privacy: .public); video=\(self.currentVideoID ?? "none", privacy: .public)")
                webView?.evaluateJavaScript("if (window.phonoDeckPlayer) { window.phonoDeckPlayer.\(command)(); }") { [weak self] _, error in
                        guard let error else { return }
                        Task { @MainActor in
                                self?.playerState = .failed(error.localizedDescription)
                    AppLog.player.error("YouTube player command \(command, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                        }
                }
        }

        private func playerHTML(videoID: String, autoplay: Bool) -> String {
                """
                <!doctype html>
                <html>
                <head>
                    <meta name="viewport" content="initial-scale=1, width=device-width">
                    <style>
                        html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #f7f7f7; overflow: hidden; }
                        body { display: flex; align-items: center; justify-content: center; }
                        #player { width: 100vw; height: 100vh; }
                    </style>
                </head>
                <body>
                    <div id="player"></div>
                    <script src="https://www.youtube.com/iframe_api"></script>
                    <script>
                        const shouldAutoplay = \(autoplay ? "true" : "false");
                        function send(event, value) {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.playerEvent) {
                                window.webkit.messageHandlers.playerEvent.postMessage({ event: event, value: value });
                            }
                        }
                        window.phonoDeckSyncVolume = function() {
                            if (window.phonoDeckPlayer && window.phonoDeckPlayer.getVolume) {
                                send('volume', window.phonoDeckPlayer.getVolume());
                                send('muted', window.phonoDeckPlayer.isMuted() ? 1 : 0);
                            }
                        };
                        window.phonoDeckSyncTime = function() {
                            if (window.phonoDeckPlayer && window.phonoDeckPlayer.getCurrentTime) {
                                send('time', window.phonoDeckPlayer.getCurrentTime());
                                send('duration', window.phonoDeckPlayer.getDuration());
                            }
                        };
                        setInterval(function() {
                            window.phonoDeckSyncTime();
                            window.phonoDeckSyncVolume();
                        }, 1000);
                        window.onYouTubeIframeAPIReady = function() {
                            window.phonoDeckPlayer = new YT.Player('player', {
                                width: '100%',
                                height: '100%',
                                videoId: '\(videoID)',
                                playerVars: {
                                    playsinline: 1,
                                    rel: 0,
                                    color: 'white',
                                    theme: 'light',
                                    enablejsapi: 1,
                                    origin: '\(appOrigin)'
                                },
                                events: {
                                    onReady: function(event) {
                                        send('ready', 0);
                                        window.phonoDeckSyncVolume();
                                        window.phonoDeckSyncTime();
                                        if (shouldAutoplay) { event.target.playVideo(); }
                                    },
                                    onStateChange: function(event) { send('state', event.data); window.phonoDeckSyncVolume(); window.phonoDeckSyncTime(); },
                                    onError: function(event) { send('error', event.data); }
                                }
                            });
                        };
                    </script>
                </body>
                </html>
                """
    }
}

struct YouTubeMusicWebPlayerView: NSViewRepresentable {
    @ObservedObject var controller: YouTubeMusicWebPlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        AppLog.player.info("Creating YouTube WKWebView")
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(context.coordinator, name: "playerEvent")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        controller.attach(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.controller = controller
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var controller: YouTubeMusicWebPlayerController

        init(controller: YouTubeMusicWebPlayerController) {
            self.controller = controller
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            AppLog.player.debug("WKWebView provisional navigation started; url=\(Self.redactedURLString(webView.url), privacy: .public)")
            Task { @MainActor in
                controller.refreshState()
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            AppLog.player.debug("WKWebView navigation committed; url=\(Self.redactedURLString(webView.url), privacy: .public)")
            Task { @MainActor in
                controller.refreshState()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AppLog.player.info("WKWebView navigation finished; title=\(webView.title ?? "none", privacy: .private), url=\(Self.redactedURLString(webView.url), privacy: .public)")
            Task { @MainActor in
                controller.refreshState()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AppLog.player.error("WKWebView navigation failed; url=\(Self.redactedURLString(webView.url), privacy: .public): \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                controller.refreshState()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            AppLog.player.error("WKWebView provisional navigation failed; url=\(Self.redactedURLString(webView.url), privacy: .public): \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in
                controller.refreshState()
            }
        }

        private static func redactedURLString(_ url: URL?) -> String {
            guard let url else { return "none" }
            return RedactedURL.string(url)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "playerEvent", let body = message.body as? [String: Any] else { return }
            Task { @MainActor in
                controller.handlePlayerMessage(body)
            }
        }
    }
}