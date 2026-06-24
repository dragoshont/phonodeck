import AppKit
import CryptoKit
import Foundation
import Security

struct GoogleOAuthClient {
    private static let callbackTimeoutNanoseconds: UInt64 = 300_000_000_000

    private let configuration: GoogleOAuthConfiguration
    private let urlSession: URLSession

    init(configuration: GoogleOAuthConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    static func fromBundle() throws -> GoogleOAuthClient {
        GoogleOAuthClient(configuration: try GoogleOAuthConfiguration.fromBundle())
    }

    func authorize() async throws -> GoogleOAuthTokenSet {
        if configuration.clientSecret == nil {
            throw GoogleOAuthError.missingClientSecret
        }
        return try await authorizeWithLoopback()
    }

    func refreshTokenSet(_ tokenSet: GoogleOAuthTokenSet) async throws -> GoogleOAuthTokenSet {
        guard let refreshToken = tokenSet.refreshToken else {
            throw GoogleOAuthError.missingRefreshToken
        }
        guard let clientSecret = configuration.clientSecret else {
            throw GoogleOAuthError.missingClientSecret
        }

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "client_id": configuration.clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidTokenResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleOAuthError.tokenExchangeFailed(httpResponse.statusCode, GoogleOAuthErrorResponse.message(from: data))
        }

        let refreshed = try JSONDecoder().decode(GoogleOAuthRefreshTokenSet.self, from: data)
        return GoogleOAuthTokenSet(
            accessToken: refreshed.accessToken,
            expiresIn: refreshed.expiresIn,
            refreshToken: tokenSet.refreshToken,
            refreshTokenExpiresIn: tokenSet.refreshTokenExpiresIn,
            scope: refreshed.scope ?? tokenSet.scope,
            tokenType: refreshed.tokenType ?? tokenSet.tokenType,
            obtainedAt: Date()
        )
    }

    private func authorizeWithLoopback() async throws -> GoogleOAuthTokenSet {
        let pkce = try PKCEPair()
        let state = try SecureRandom.urlSafeString(byteCount: 32)
        let server = try OAuthLoopbackServer(callbackPath: configuration.redirectPath)
        try server.start()

        let authorizationURL = try configuration.authorizationURL(
            redirectURI: server.redirectURI,
            state: state,
            codeChallenge: pkce.challenge
        )

        let openedBrowser = await MainActor.run {
            NSWorkspace.shared.open(authorizationURL)
        }
        guard openedBrowser else {
            server.cancel()
            throw GoogleOAuthError.browserOpenFailed
        }

        let callback = try await Self.waitForCallback(on: server, timeoutNanoseconds: Self.callbackTimeoutNanoseconds)
        guard callback.state == state else {
            throw GoogleOAuthError.stateMismatch
        }
        if let error = callback.error {
            throw GoogleOAuthError.authorizationDenied(error)
        }
        guard let code = callback.code else {
            throw GoogleOAuthError.missingAuthorizationCode
        }

        return try await exchangeAuthorizationCode(
            code,
            codeVerifier: pkce.verifier,
            redirectURI: server.redirectURI
        )
    }

    private static func waitForCallback(on server: OAuthLoopbackServer, timeoutNanoseconds: UInt64) async throws -> OAuthCallback {
        try await withThrowingTaskGroup(of: OAuthCallback.self) { group in
            group.addTask {
                try await server.waitForCallback()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw GoogleOAuthError.authorizationTimedOut
            }

            guard let callback = try await group.next() else {
                throw GoogleOAuthError.authorizationTimedOut
            }
            group.cancelAll()
            return callback
        }
    }

    private func exchangeAuthorizationCode(_ code: String, codeVerifier: String, redirectURI: String) async throws -> GoogleOAuthTokenSet {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var formValues = [
            "client_id": configuration.clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        if let clientSecret = configuration.clientSecret {
            formValues["client_secret"] = clientSecret
        }
        request.httpBody = FormURLEncoder.encode(formValues)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidTokenResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleOAuthError.tokenExchangeFailed(httpResponse.statusCode, GoogleOAuthErrorResponse.message(from: data))
        }

        var tokenSet = try JSONDecoder().decode(GoogleOAuthTokenSet.self, from: data)
        tokenSet.obtainedAt = Date()
        return tokenSet
    }
}

struct GoogleOAuthConfiguration {
    static let currentFeatureScopes = ["https://www.googleapis.com/auth/youtube"]

    let clientID: String
    let clientSecret: String?
    let scopes: [String]
    let redirectPath: String

    let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    static func fromBundle(_ bundle: Bundle = .main) throws -> GoogleOAuthConfiguration {
        let rawClientID = usableBundleString(named: "GoogleOAuthClientID", in: bundle)

        guard let clientID = rawClientID else {
            throw GoogleOAuthError.missingClientID
        }

        return GoogleOAuthConfiguration(
            clientID: clientID,
            clientSecret: usableBundleString(named: "GoogleOAuthClientSecret", in: bundle),
            scopes: currentFeatureScopes,
            redirectPath: "/oauth/google/callback"
        )
    }

    static func bundleStatus(_ bundle: Bundle = .main) -> GoogleOAuthConfigurationStatus {
        GoogleOAuthConfigurationStatus(
            hasClientID: usableBundleString(named: "GoogleOAuthClientID", in: bundle) != nil,
            hasClientSecret: usableBundleString(named: "GoogleOAuthClientSecret", in: bundle) != nil
        )
    }

    static func usableBundleString(named key: String, in bundle: Bundle = .main) -> String? {
        let rawValue = (bundle.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty, !rawValue.contains("$(") else { return nil }
        return rawValue
    }

    func authorizationURL(redirectURI: String, state: String, codeChallenge: String) throws -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else {
            throw GoogleOAuthError.invalidAuthorizationURL
        }
        return url
    }
}

struct GoogleOAuthConfigurationStatus: Equatable {
    let hasClientID: Bool
    let hasClientSecret: Bool
}

struct GoogleOAuthTokenSet: Codable, Equatable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let refreshTokenExpiresIn: Int?
    let scope: String
    let tokenType: String
    var obtainedAt: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case scope
        case tokenType = "token_type"
        case obtainedAt
    }
}

private struct GoogleOAuthRefreshTokenSet: Codable, Equatable {
    let accessToken: String
    let expiresIn: Int
    let scope: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}

private struct GoogleOAuthErrorResponse: Codable, Equatable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    static func message(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(GoogleOAuthErrorResponse.self, from: data) {
            return decoded.errorDescription ?? decoded.error
        }
        let body = String(data: data, encoding: .utf8) ?? "Unknown Google error."
        return body.count > 500 ? String(body.prefix(500)) : body
    }
}

enum GoogleOAuthError: LocalizedError, Equatable {
    case authorizationDenied(String)
    case authorizationTimedOut
    case browserOpenFailed
    case invalidAuthorizationURL
    case invalidCallbackRequest
    case invalidTokenResponse
    case missingAuthorizationCode
    case missingClientID
    case missingClientSecret
    case missingRequiredScope(String)
    case missingRefreshToken
    case noAvailableLoopbackPort
    case randomGenerationFailed(OSStatus)
    case stateMismatch
    case tokenExchangeFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            "Google authorization failed: \(message)"
        case .authorizationTimedOut:
            "Google sign-in timed out. Try connecting again."
        case .browserOpenFailed:
            "Could not open the system browser for Google sign-in."
        case .invalidAuthorizationURL:
            "Could not build Google authorization URL."
        case .invalidCallbackRequest:
            "The OAuth callback request was invalid."
        case .invalidTokenResponse:
            "Google returned an invalid token response."
        case .missingAuthorizationCode:
            "Google did not return an authorization code."
        case .missingClientID:
            "Missing Google OAuth client ID. Add GOOGLE_OAUTH_CLIENT_ID to Config/Secrets.xcconfig."
        case .missingClientSecret:
            "Missing Google OAuth client secret. Add GOOGLE_OAUTH_CLIENT_SECRET to Config/Secrets.xcconfig."
        case .missingRequiredScope:
            "Reconnect Google to allow YouTube Music playlist changes."
        case .missingRefreshToken:
            "Missing Google refresh token. Disconnect and connect Google again."
        case .noAvailableLoopbackPort:
            "Could not open a localhost callback port for Google OAuth."
        case .randomGenerationFailed(let status):
            "Secure random generation failed with status \(status)."
        case .stateMismatch:
            "Google OAuth state did not match."
        case .tokenExchangeFailed(let statusCode, let body):
            "Google token exchange failed (HTTP \(statusCode)): \(body)"
        }
    }
}

private struct PKCEPair {
    let verifier: String
    let challenge: String

    init() throws {
        verifier = try SecureRandom.urlSafeString(byteCount: 64)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        challenge = Data(digest).base64URLEncodedString()
    }
}

private enum SecureRandom {
    static func urlSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw GoogleOAuthError.randomGenerationFailed(status)
        }
        return Data(bytes).base64URLEncodedString()
    }
}

enum FormURLEncoder {
    static func encode(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
