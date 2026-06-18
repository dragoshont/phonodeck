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
        let pkce = try PKCEPair()
        let state = try SecureRandom.urlSafeString(byteCount: 32)
        let server = try OAuthLoopbackServer(callbackPath: configuration.redirectPath)
        try server.start()

        let authorizationURL = try configuration.authorizationURL(
            redirectURI: server.redirectURI,
            state: state,
            codeChallenge: pkce.challenge
        )

        await MainActor.run {
            _ = NSWorkspace.shared.open(authorizationURL)
        }

        let callback = try await server.waitForCallback()
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

    private func exchangeAuthorizationCode(_ code: String, codeVerifier: String, redirectURI: String) async throws -> GoogleOAuthTokenSet {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "client_id": configuration.clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ])

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
    let scopes: [String]
    let redirectPath: String

    let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    static func fromBundle() throws -> GoogleOAuthConfiguration {
        let rawClientID = (Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawClientID.isEmpty, !rawClientID.contains("$(") else {
            throw GoogleOAuthError.missingClientID
        }

        return GoogleOAuthConfiguration(
            clientID: rawClientID,
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

enum GoogleOAuthError: LocalizedError, Equatable {
    case authorizationDenied(String)
    case invalidAuthorizationURL
    case invalidCallbackRequest
    case invalidTokenResponse
    case missingAuthorizationCode
    case missingClientID
    case randomGenerationFailed(OSStatus)
    case stateMismatch
    case tokenExchangeFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let message):
            "Google authorization failed: \(message)"
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
