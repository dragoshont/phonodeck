import AppKit
import Foundation

/// Plex sign-in via the PIN flow: create a PIN, open the browser to plex.tv/auth,
/// then poll until the user approves and a token is issued. Also reads the
/// account (for Plex Pass detection).
struct PlexAuthClient: Sendable {
    private let urlSession: URLSession
    private static let pollTimeout: TimeInterval = 300
    private static let pollIntervalNanoseconds: UInt64 = 1_500_000_000

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Interactive sign-in: create PIN → open browser → poll for the token.
    func authenticate() async throws -> String {
        let pin = try await createPIN()
        let opened = await MainActor.run { NSWorkspace.shared.open(Self.authURL(code: pin.code)) }
        guard opened else { throw PlexAuthError.browserOpenFailed }
        return try await pollForToken(pinID: pin.id, code: pin.code)
    }

    func createPIN() async throws -> PlexPIN {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins?strong=true")!)
        request.httpMethod = "POST"
        PlexClient.apply(headers: nil, to: &request)
        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(PlexPIN.self, from: data)
    }

    func pollForToken(pinID: Int, code: String) async throws -> String {
        let deadline = Date().addingTimeInterval(Self.pollTimeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if let token = try await checkPIN(pinID: pinID, code: code), !token.isEmpty {
                return token
            }
            try await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
        }
        throw PlexAuthError.timedOut
    }

    func checkPIN(pinID: Int, code: String) async throws -> String? {
        var components = URLComponents(string: "https://plex.tv/api/v2/pins/\(pinID)")!
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        var request = URLRequest(url: components.url!)
        PlexClient.apply(headers: nil, to: &request)
        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(PlexPIN.self, from: data).authToken
    }

    /// Account info — used to detect Plex Pass (premium tier).
    func currentUser(token: String) async throws -> PlexUser {
        var request = URLRequest(url: URL(string: "https://plex.tv/api/v2/user")!)
        PlexClient.apply(headers: token, to: &request)
        let (data, response) = try await urlSession.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(PlexUser.self, from: data)
    }

    /// The plex.tv hosted sign-in page (hash-fragment params).
    static func authURL(code: String) -> URL {
        let id = PlexClient.identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? PlexClient.identifier
        let product = PlexClient.product.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? PlexClient.product
        let string = "https://app.plex.tv/auth#?clientID=\(id)&code=\(code)&context%5Bdevice%5D%5Bproduct%5D=\(product)"
        return URL(string: string)!
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw PlexAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw PlexAuthError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

struct PlexPIN: Decodable, Equatable {
    let id: Int
    let code: String
    let authToken: String?
}

struct PlexUser: Decodable, Equatable {
    let username: String?
    let title: String?
    let subscription: Subscription?

    struct Subscription: Decodable, Equatable {
        let active: Bool?
    }

    var displayName: String { title ?? username ?? "Plex" }
    var hasPlexPass: Bool { subscription?.active ?? false }
    var tier: SourceAccountTier { hasPlexPass ? .premium : .free }
}

enum PlexAuthError: LocalizedError, Equatable {
    case browserOpenFailed
    case timedOut
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .browserOpenFailed: "Could not open the system browser for Plex sign-in."
        case .timedOut: "Plex sign-in timed out. Try connecting again."
        case .invalidResponse: "Plex returned an invalid response."
        case .requestFailed(let status, let body): "Plex sign-in failed (HTTP \(status)): \(body)"
        }
    }
}
