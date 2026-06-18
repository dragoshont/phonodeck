import AppKit
import Foundation

@MainActor
final class YouTubeAccountViewModel: ObservableObject {
    @Published private(set) var state: YouTubeAccountState = .signedOut
    @Published private(set) var pollStatus: String = ""

    private let accountStore = GoogleAccountStore()
    private let dataClient = YouTubeDataClient()
    private var activeDeviceAuthorization: GoogleDeviceAuthorization?
    private var isPolling = false
    private var pollCount = 0
    private var pollingTask: Task<Void, Never>?

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
        pollStatus = "Requesting code from Google..."
        do {
            let oauthClient = try GoogleOAuthClient.fromBundle()
            let authorization = try await oauthClient.startDeviceAuthorization()
            activeDeviceAuthorization = authorization
            state = .deviceCode(userCode: authorization.userCode, verificationURL: authorization.preferredVerificationURL)
            pollCount = 0
            pollStatus = "Enter the code in Google, then wait here. Polling will continue automatically."

            _ = NSWorkspace.shared.open(authorization.preferredVerificationURL)
            startPollingCurrentDeviceAuthorization()
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func startPollingCurrentDeviceAuthorization() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self.checkCurrentDeviceAuthorizationOnce()
                if case .connected = self.state {
                    return
                }
            }
        }
    }

    func finishCurrentDeviceAuthorization() async {
        guard !isPolling else { return }
        guard let authorization = activeDeviceAuthorization else { return }

        isPolling = true
        state = .waitingForApproval(userCode: authorization.userCode, verificationURL: authorization.preferredVerificationURL)
        defer { isPolling = false }

        do {
            let tokens = try await GoogleOAuthClient.fromBundle().finishDeviceAuthorization(authorization)
            try accountStore.save(tokens: tokens)
            activeDeviceAuthorization = nil
            pollStatus = "Google tokens stored. Fetching YouTube channel..."

            let channel = try await dataClient.currentChannel(accessToken: tokens.accessToken)
            state = .connected(channelTitle: channel?.snippet.title ?? "YouTube account", scope: tokens.scope)
            pollStatus = "Connected to YouTube."
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func checkCurrentDeviceAuthorizationOnce() async {
        guard let authorization = activeDeviceAuthorization else {
            pollStatus = "No active Google code. Click Connect Google again."
            return
        }
        pollCount += 1
        pollStatus = "Checking Google authorization... attempt \(pollCount)"
        do {
            guard let tokens = try await GoogleOAuthClient.fromBundle().pollDeviceTokenOnce(authorization) else {
                pollStatus = "Waiting for Google approval... attempt \(pollCount)"
                return
            }
            try accountStore.save(tokens: tokens)
            activeDeviceAuthorization = nil
            pollingTask?.cancel()
            pollingTask = nil
            pollStatus = "Google tokens stored. Fetching YouTube channel..."

            let channel = try await dataClient.currentChannel(accessToken: tokens.accessToken)
            state = .connected(channelTitle: channel?.snippet.title ?? "YouTube account", scope: tokens.scope)
            pollStatus = "Connected to YouTube."
        } catch let oauthError as GoogleOAuthError {
            switch oauthError {
            case .deviceCodeExpired, .authorizationDenied:
                pollStatus = oauthError.localizedDescription
                state = .failed(oauthError.localizedDescription)
            default:
                pollStatus = oauthError.localizedDescription
                return
            }
        } catch {
            pollStatus = error.localizedDescription
            return
        }
    }

    func disconnect() {
        do {
            try accountStore.disconnect()
            activeDeviceAuthorization = nil
            pollingTask?.cancel()
            pollingTask = nil
            pollStatus = ""
            state = .signedOut
        } catch {
            pollStatus = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }
}

enum YouTubeAccountState: Equatable {
    case signedOut
    case connecting
    case deviceCode(userCode: String, verificationURL: URL)
    case waitingForApproval(userCode: String, verificationURL: URL)
    case connected(channelTitle: String, scope: String)
    case stored(scope: String)
    case failed(String)

    var title: String {
        switch self {
        case .signedOut: "Not connected"
        case .connecting: "Connecting"
        case .deviceCode: "Enter code in browser"
        case .waitingForApproval: "Waiting for approval"
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
            "Requesting Google code"
        case .deviceCode(let userCode, _):
            "Code \(userCode)"
        case .waitingForApproval(let userCode, _):
            "Approved in browser? Code \(userCode)"
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
        case .connecting, .deviceCode, .waitingForApproval:
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
