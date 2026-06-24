import Foundation
import OSLog

@MainActor
final class YouTubeAccountViewModel: ObservableObject {
    @Published private(set) var state: YouTubeAccountState = .signedOut
    @Published private(set) var pollStatus: String = ""

    private let accountStore = GoogleAccountStore()
    private let dataClient = YouTubeDataClient()

    init() {
        AppLog.auth.info("Initializing YouTube account state")
        do {
            if let tokens = try accountStore.loadTokens() {
                state = .stored(scope: tokens.scope)
                AppLog.auth.info("Stored Google tokens found; scope count=\(tokens.scope.split(separator: " ").count, privacy: .public)")
            } else {
                let status = GoogleOAuthConfiguration.bundleStatus()
                if status.hasClientID, !status.hasClientSecret {
                    pollStatus = "Google OAuth is missing the local client secret. Add GOOGLE_OAUTH_CLIENT_SECRET to Config/Secrets.xcconfig."
                    AppLog.auth.warning("Google OAuth client ID exists but client secret is missing")
                } else {
                    AppLog.auth.info("No stored Google tokens found; signed out")
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
            AppLog.auth.error("Failed to load stored Google token state: \(error.localizedDescription, privacy: .public)")
        }
    }

    func connect() async {
        AppLog.auth.info("Google login started")
        state = .connecting
        pollStatus = "Opening Google sign-in..."
        do {
            let tokens = try await GoogleOAuthClient.fromBundle().authorize()
            AppLog.auth.info("Google OAuth authorization completed; scope count=\(tokens.scope.split(separator: " ").count, privacy: .public)")
            try accountStore.save(tokens: tokens)
            AppLog.auth.info("Google tokens saved to Keychain")
            pollStatus = "Google tokens stored. Fetching YouTube channel..."

            let channel = try await dataClient.currentChannel(accessToken: tokens.accessToken)
            state = .connected(channelTitle: channel?.snippet.title ?? "YouTube account", scope: tokens.scope)
            pollStatus = "Connected to YouTube."
            AppLog.auth.info("Google login connected; channel loaded=\((channel != nil).description, privacy: .public)")
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
            AppLog.auth.error("Google login failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshStoredAccount() async {
        guard case .stored = state else { return }
        AppLog.auth.info("Refreshing stored Google account")
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                state = .signedOut
                AppLog.auth.warning("Stored Google account refresh found no tokens; signed out")
                return
            }
            let channel = try await dataClient.currentChannel(accessToken: tokens.accessToken)
            state = .connected(channelTitle: channel?.snippet.title ?? "YouTube account", scope: tokens.scope)
            pollStatus = ""
            AppLog.auth.info("Stored Google account refreshed; channel loaded=\((channel != nil).description, privacy: .public)")
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
            AppLog.auth.error("Stored Google account refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() {
        AppLog.auth.info("Google logout requested")
        do {
            try accountStore.disconnect()
            LocalPrivacyDataStore.clearYouTubeAuthorizedData()
            pollStatus = ""
            state = .signedOut
            AppLog.auth.info("Google logout completed; Keychain token and authorized local data removed")
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
            AppLog.auth.error("Google logout failed: \(error.localizedDescription, privacy: .public)")
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
            "Browser sign-in"
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
    case secondary
}
