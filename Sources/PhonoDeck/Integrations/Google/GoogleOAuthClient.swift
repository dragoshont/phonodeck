import AppKit
import CryptoKit
import Foundation
import Security

struct GoogleOAuthClient {
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
            return try await authorizeWithDeviceFlow()
        }
        return try await authorizeWithLoopback()
    }

    func startDeviceAuthorization() async throws -> GoogleDeviceAuthorization {
        try await requestDeviceAuthorization()
    }

    func finishDeviceAuthorization(_ authorization: GoogleDeviceAuthorization) async throws -> GoogleOAuthTokenSet {
        try await pollDeviceToken(authorization)
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

        let callbackTask = Task {
            try await server.waitForCallback()
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            _ = NSWorkspace.shared.open(authorizationURL)
        }

        let callback = try await callbackTask.value
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

    private func authorizeWithDeviceFlow() async throws -> GoogleOAuthTokenSet {
        let deviceAuthorization = try await requestDeviceAuthorization()

        await MainActor.run {
            _ = NSWorkspace.shared.open(deviceAuthorization.verificationURLComplete ?? deviceAuthorization.verificationURL)
        }

        return try await pollDeviceToken(deviceAuthorization)
    }

    private func requestDeviceAuthorization() async throws -> GoogleDeviceAuthorization {
        var request = URLRequest(url: configuration.deviceCodeEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "client_id": configuration.clientID,
            "scope": configuration.scopes.joined(separator: " ")
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidTokenResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw GoogleOAuthError.deviceAuthorizationFailed(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(GoogleDeviceAuthorization.self, from: data)
    }

    func pollDeviceTokenOnce(_ authorization: GoogleDeviceAuthorization) async throws -> GoogleOAuthTokenSet? {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "client_id": configuration.clientID,
            "device_code": authorization.deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidTokenResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            var tokenSet = try JSONDecoder().decode(GoogleOAuthTokenSet.self, from: data)
            tokenSet.obtainedAt = Date()
            return tokenSet
        }

        let tokenError = try? JSONDecoder().decode(GoogleOAuthTokenError.self, from: data)
        switch tokenError?.error {
        case "authorization_pending", "slow_down":
            return nil
        case "access_denied":
            throw GoogleOAuthError.authorizationDenied(tokenError?.errorDescription ?? "access_denied")
        case "expired_token":
            throw GoogleOAuthError.deviceCodeExpired
        default:
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw GoogleOAuthError.tokenExchangeFailed(httpResponse.statusCode, responseBody)
        }
    }

    private func pollDeviceToken(_ authorization: GoogleDeviceAuthorization) async throws -> GoogleOAuthTokenSet {
        var pollInterval = authorization.interval ?? 5
        let expirationDate = Date().addingTimeInterval(TimeInterval(authorization.expiresIn))

        while Date() < expirationDate {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            if let tokenSet = try await pollDeviceTokenOnce(authorization) {
                return tokenSet
            }
        }

        throw GoogleOAuthError.deviceCodeExpired
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
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw GoogleOAuthError.tokenExchangeFailed(httpResponse.statusCode, responseBody)
        }

        var tokenSet = try JSONDecoder().decode(GoogleOAuthTokenSet.self, from: data)
        tokenSet.obtainedAt = Date()
        return tokenSet
    }
}

struct GoogleOAuthConfiguration {
    let clientID: String
    let clientSecret: String?
    let scopes: [String]
    let redirectPath: String

    let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    let deviceCodeEndpoint = URL(string: "https://oauth2.googleapis.com/device/code")!
    let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    static func fromBundle() throws -> GoogleOAuthConfiguration {
        let rawClientID = (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawClientID.isEmpty, !rawClientID.contains("$(") else {
            throw GoogleOAuthError.missingClientID
        }

        let rawClientSecret = (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientSecret") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = rawClientSecret.isEmpty || rawClientSecret.contains("$(") ? nil : rawClientSecret

        return GoogleOAuthConfiguration(
            clientID: rawClientID,
            clientSecret: clientSecret,
            scopes: ["https://www.googleapis.com/auth/youtube.readonly"],
            redirectPath: "/oauth/google/callback"
        )
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

struct GoogleOAuthTokenSet: Codable, Equatable {
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

struct GoogleDeviceAuthorization: Codable, Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let verificationURLComplete: URL?
    let expiresIn: Int
    let interval: Int?

    var preferredVerificationURL: URL {
        verificationURLComplete ?? verificationURL
    }

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURL = "verification_url"
        case verificationURLComplete = "verification_url_complete"
        case expiresIn = "expires_in"
        case interval
    }
}

struct GoogleOAuthTokenError: Codable, Equatable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

enum GoogleOAuthError: LocalizedError, Equatable {
    case authorizationDenied(String)
    case deviceAuthorizationFailed(Int, String)
    case deviceCodeExpired
    case invalidAuthorizationURL
    case invalidCallbackRequest
    case invalidTokenResponse
    case missingAuthorizationCode
    case missingClientID
    case noAvailableLoopbackPort
    case randomGenerationFailed(OSStatus)
    case stateMismatch
    case tokenExchangeFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            "Google authorization failed: \(message)"
        case .deviceAuthorizationFailed(let statusCode, let body):
            "Google device authorization failed (HTTP \(statusCode)): \(body)"
        case .deviceCodeExpired:
            "Google device authorization expired. Try connecting again."
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

private enum FormURLEncoder {
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
