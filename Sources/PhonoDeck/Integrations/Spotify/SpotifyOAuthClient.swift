import AppKit
import Foundation

/// Spotify Authorization Code + PKCE client (no client secret). Mirrors the
/// Google desktop flow: system browser + loopback redirect. Spotify requires the
/// redirect URI to match a registered one EXACTLY, so the loopback server binds
/// to a fixed port (`http://127.0.0.1:8888/callback`).
struct SpotifyOAuthClient {
    private static let callbackTimeoutNanoseconds: UInt64 = 300_000_000_000

    private let configuration: SpotifyOAuthConfiguration
    private let urlSession: URLSession

    init(configuration: SpotifyOAuthConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    static func fromBundle() throws -> SpotifyOAuthClient {
        SpotifyOAuthClient(configuration: try SpotifyOAuthConfiguration.fromBundle())
    }

    func authorize() async throws -> SpotifyOAuthTokenSet {
        let pkce = try OAuthPKCE()
        let state = try OAuthRandom.urlSafeString(byteCount: 32)
        let server = try OAuthLoopbackServer(
            callbackPath: configuration.redirectPath,
            portRange: configuration.loopbackPort...configuration.loopbackPort
        )
        try server.start()

        let authorizationURL = try configuration.authorizationURL(
            redirectURI: server.redirectURI,
            state: state,
            codeChallenge: pkce.challenge
        )

        let opened = await MainActor.run { NSWorkspace.shared.open(authorizationURL) }
        guard opened else {
            server.cancel()
            throw SpotifyOAuthError.browserOpenFailed
        }

        let callback = try await Self.waitForCallback(on: server, timeoutNanoseconds: Self.callbackTimeoutNanoseconds)
        guard callback.state == state else { throw SpotifyOAuthError.stateMismatch }
        if let error = callback.error { throw SpotifyOAuthError.authorizationDenied(error) }
        guard let code = callback.code else { throw SpotifyOAuthError.missingAuthorizationCode }

        return try await exchangeAuthorizationCode(code, codeVerifier: pkce.verifier, redirectURI: server.redirectURI)
    }

    func refreshTokenSet(_ tokenSet: SpotifyOAuthTokenSet) async throws -> SpotifyOAuthTokenSet {
        guard let refreshToken = tokenSet.refreshToken else { throw SpotifyOAuthError.missingRefreshToken }

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.clientID
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyOAuthError.invalidTokenResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SpotifyOAuthError.tokenExchangeFailed(http.statusCode, SpotifyOAuthErrorResponse.message(from: data))
        }

        var refreshed = try JSONDecoder().decode(SpotifyOAuthTokenSet.self, from: data)
        // Spotify often omits a new refresh_token on refresh; keep the old one.
        if refreshed.refreshToken == nil { refreshed.refreshToken = tokenSet.refreshToken }
        refreshed.obtainedAt = Date()
        return refreshed
    }

    private func exchangeAuthorizationCode(_ code: String, codeVerifier: String, redirectURI: String) async throws -> SpotifyOAuthTokenSet {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": configuration.clientID,
            "code_verifier": codeVerifier
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyOAuthError.invalidTokenResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SpotifyOAuthError.tokenExchangeFailed(http.statusCode, SpotifyOAuthErrorResponse.message(from: data))
        }

        var tokenSet = try JSONDecoder().decode(SpotifyOAuthTokenSet.self, from: data)
        tokenSet.obtainedAt = Date()
        return tokenSet
    }

    private static func waitForCallback(on server: OAuthLoopbackServer, timeoutNanoseconds: UInt64) async throws -> OAuthCallback {
        try await withThrowingTaskGroup(of: OAuthCallback.self) { group in
            group.addTask { try await server.waitForCallback() }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw SpotifyOAuthError.authorizationTimedOut
            }
            guard let callback = try await group.next() else { throw SpotifyOAuthError.authorizationTimedOut }
            group.cancelAll()
            return callback
        }
    }
}

struct SpotifyOAuthConfiguration {
    let clientID: String
    let scopes: [String]
    let redirectPath: String
    let loopbackPort: Int

    let authorizationEndpoint = URL(string: "https://accounts.spotify.com/authorize")!
    let tokenEndpoint = URL(string: "https://accounts.spotify.com/api/token")!

    /// Scopes for library/playlists/search + profile (product = free/premium).
    static let defaultScopes = [
        "user-read-private",
        "user-read-email",
        "user-library-read",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-top-read",
        "user-read-recently-played"
    ]

    static func fromBundle(_ bundle: Bundle = .main) throws -> SpotifyOAuthConfiguration {
        guard let clientID = usableBundleString(named: "SpotifyOAuthClientID", in: bundle) else {
            throw SpotifyOAuthError.missingClientID
        }
        return SpotifyOAuthConfiguration(
            clientID: clientID,
            scopes: defaultScopes,
            redirectPath: "/callback",
            loopbackPort: 8888
        )
    }

    static func isConfigured(_ bundle: Bundle = .main) -> Bool {
        usableBundleString(named: "SpotifyOAuthClientID", in: bundle) != nil
    }

    static func usableBundleString(named key: String, in bundle: Bundle = .main) -> String? {
        let raw = (bundle.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !raw.contains("$(") else { return nil }
        return raw
    }

    func authorizationURL(redirectURI: String, state: String, codeChallenge: String) throws -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else { throw SpotifyOAuthError.invalidAuthorizationURL }
        return url
    }
}

struct SpotifyOAuthTokenSet: Codable, Equatable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String?
    let expiresIn: Int
    var refreshToken: String?
    var obtainedAt: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case obtainedAt
    }

    /// Considered fresh until 60 seconds before expiry.
    var isFresh: Bool {
        guard let obtainedAt else { return false }
        return Date().timeIntervalSince(obtainedAt) < TimeInterval(max(expiresIn - 60, 0))
    }
}

struct SpotifyOAuthErrorResponse: Codable, Equatable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    static func message(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(SpotifyOAuthErrorResponse.self, from: data) {
            return decoded.errorDescription ?? decoded.error
        }
        let body = String(data: data, encoding: .utf8) ?? "Unknown Spotify error."
        return body.count > 500 ? String(body.prefix(500)) : body
    }
}

enum SpotifyOAuthError: LocalizedError, Equatable {
    case authorizationDenied(String)
    case authorizationTimedOut
    case browserOpenFailed
    case invalidAuthorizationURL
    case invalidTokenResponse
    case missingAuthorizationCode
    case missingClientID
    case missingRefreshToken
    case stateMismatch
    case tokenExchangeFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message): "Spotify authorization failed: \(message)"
        case .authorizationTimedOut: "Spotify sign-in timed out. Try connecting again."
        case .browserOpenFailed: "Could not open the system browser for Spotify sign-in."
        case .invalidAuthorizationURL: "Could not build the Spotify authorization URL."
        case .invalidTokenResponse: "Spotify returned an invalid token response."
        case .missingAuthorizationCode: "Spotify did not return an authorization code."
        case .missingClientID: "Missing Spotify client ID. Add SPOTIFY_OAUTH_CLIENT_ID to Config/Secrets.xcconfig."
        case .missingRefreshToken: "Missing Spotify refresh token. Disconnect and connect Spotify again."
        case .stateMismatch: "Spotify OAuth state did not match."
        case .tokenExchangeFailed(let status, let body): "Spotify token exchange failed (HTTP \(status)): \(body)"
        }
    }
}
