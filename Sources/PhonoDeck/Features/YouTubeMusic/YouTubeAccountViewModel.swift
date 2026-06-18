import Foundation

@MainActor
final class YouTubeAccountViewModel: ObservableObject {
    @Published private(set) var state: YouTubeAccountState = .signedOut

    private let accountStore = GoogleAccountStore()
    private let dataClient = YouTubeDataClient()

    init() {
        do {
            if let tokens = try accountStore.loadTokens() {
                state = .stored(scope: tokens.scope)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func connect() async {
        state = .connecting
        do {
            let tokens = try await GoogleOAuthClient.fromBundle().authorize()
            try accountStore.save(tokens: tokens)

            let channel = try await dataClient.currentChannel(accessToken: tokens.accessToken)
            state = .connected(channelTitle: channel?.snippet.title ?? "YouTube account", scope: tokens.scope)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        do {
            try accountStore.disconnect()
            state = .signedOut
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum YouTubeAccountState: Equatable {
    case signedOut
    case connecting
    case connected(channelTitle: String, scope: String)
    case stored(scope: String)
    case failed(String)

    var title: String {
        switch self {
        case .signedOut: "Not connected"
        case .connecting: "Connecting"
        case .connected(let channelTitle, _): channelTitle
        case .stored: "Token stored"
        case .failed: "Connection failed"
        }
    }

    var detail: String {
        switch self {
        case .signedOut:
            "Google OAuth required"
        case .connecting:
            "Waiting for browser sign-in"
        case .connected(_, let scope):
            scope
        case .stored(let scope):
            scope
        case .failed(let message):
            message
        }
    }

    var statusColor: ColorName {
        switch self {
        case .signedOut, .stored:
            .orange
        case .connecting:
            .blue
        case .connected:
            .green
        case .failed:
            .red
        }
    }
}

enum ColorName: Equatable {
    case blue
    case green
    case orange
    case red
}
