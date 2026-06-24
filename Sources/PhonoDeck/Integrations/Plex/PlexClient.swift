import Foundation

/// Stable client identity + standard headers for the Plex APIs. Plex requires a
/// persistent `X-Plex-Client-Identifier` per install and identifying product
/// headers on every request.
enum PlexClient {
    static let product = "PhonoDeck"
    static let version = "0.1"
    static let device = "macOS"
    static let deviceName = "PhonoDeck"
    static let platform = "macOS"

    private static let identifierKey = "plexClientIdentifier"

    /// A persistent per-install identifier (generated once, stored in UserDefaults).
    static var identifier: String {
        if let existing = UserDefaults.standard.string(forKey: identifierKey), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: identifierKey)
        return generated
    }

    static func headers(token: String? = nil) -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "X-Plex-Product": product,
            "X-Plex-Version": version,
            "X-Plex-Client-Identifier": identifier,
            "X-Plex-Device": device,
            "X-Plex-Device-Name": deviceName,
            "X-Plex-Platform": platform
        ]
        if let token { headers["X-Plex-Token"] = token }
        return headers
    }

    static func apply(headers token: String?, to request: inout URLRequest) {
        for (key, value) in headers(token: token) {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}

/// Persisted Plex credentials: the long-lived auth token plus the resolved server
/// connection. Plex tokens do not expire like OAuth access tokens.
struct PlexCredentials: Codable, Equatable, Sendable {
    let token: String
    var serverName: String?
    var serverBaseURL: String?
    var hasPlexPass: Bool
}

/// Stores Plex credentials in the Keychain. Mirrors the other account stores.
protocol PlexCredentialStoring: Sendable {
    func load() throws -> PlexCredentials?
    func save(_ credentials: PlexCredentials) throws
    func disconnect() throws
}

struct PlexAccountStore: PlexCredentialStoring {
    private let keychain = KeychainStore(service: "ro.hont.phonodeck.plex")
    private let account = "plex-credentials"

    func load() throws -> PlexCredentials? {
        guard let data = try keychain.load(account: account) else { return nil }
        return try JSONDecoder().decode(PlexCredentials.self, from: data)
    }

    func save(_ credentials: PlexCredentials) throws {
        try keychain.save(try JSONEncoder().encode(credentials), account: account)
    }

    func disconnect() throws {
        try keychain.delete(account: account)
    }
}
