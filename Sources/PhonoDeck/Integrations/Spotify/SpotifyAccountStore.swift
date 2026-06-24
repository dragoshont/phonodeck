import Foundation

/// Stores Spotify OAuth tokens in the Keychain and refreshes them on demand.
/// Mirrors `GoogleAccountStore`.
protocol SpotifyCredentialStoring: Sendable {
    func loadTokens() throws -> SpotifyOAuthTokenSet?
    func loadFreshTokens() async throws -> SpotifyOAuthTokenSet?
    func save(tokens: SpotifyOAuthTokenSet) throws
    func disconnect() throws
}

struct SpotifyAccountStore: SpotifyCredentialStoring {
    private let keychain = KeychainStore(service: "ro.hont.phonodeck.spotify")
    private let tokenAccount = "spotify-oauth-tokens"

    func loadTokens() throws -> SpotifyOAuthTokenSet? {
        guard let data = try keychain.load(account: tokenAccount) else { return nil }
        return try JSONDecoder().decode(SpotifyOAuthTokenSet.self, from: data)
    }

    func loadFreshTokens() async throws -> SpotifyOAuthTokenSet? {
        guard let tokens = try loadTokens() else { return nil }
        guard !tokens.isFresh else { return tokens }
        let refreshed = try await SpotifyOAuthClient.fromBundle().refreshTokenSet(tokens)
        try save(tokens: refreshed)
        return refreshed
    }

    func save(tokens: SpotifyOAuthTokenSet) throws {
        try keychain.save(try JSONEncoder().encode(tokens), account: tokenAccount)
    }

    func disconnect() throws {
        try keychain.delete(account: tokenAccount)
    }
}
