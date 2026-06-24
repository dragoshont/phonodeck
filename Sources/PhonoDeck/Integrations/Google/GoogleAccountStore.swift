import Foundation

struct GoogleAccountStore: Sendable {
    private let keychain = KeychainStore(service: "ro.hont.phonodeck.google")
    private let tokenAccount = "youtube-oauth-tokens"

    func loadTokens() throws -> GoogleOAuthTokenSet? {
        guard let data = try keychain.load(account: tokenAccount) else { return nil }
        return try JSONDecoder().decode(GoogleOAuthTokenSet.self, from: data)
    }

    func loadFreshTokens() async throws -> GoogleOAuthTokenSet? {
        guard let tokens = try loadTokens() else { return nil }
        guard !tokens.isFresh else {
            return tokens
        }

        let refreshedTokens = try await GoogleOAuthClient.fromBundle().refreshTokenSet(tokens)
        try save(tokens: refreshedTokens)
        return refreshedTokens
    }

    func loadFreshTokens(requiredScope: String) async throws -> GoogleOAuthTokenSet? {
        guard let tokens = try await loadFreshTokens() else { return nil }
        guard tokens.grants(scope: requiredScope) else {
            throw GoogleOAuthError.missingRequiredScope(requiredScope)
        }
        return tokens
    }

    func save(tokens: GoogleOAuthTokenSet) throws {
        let data = try JSONEncoder().encode(tokens)
        try keychain.save(data, account: tokenAccount)
    }

    func disconnect() throws {
        try keychain.delete(account: tokenAccount)
    }
}

private extension GoogleOAuthTokenSet {
    var isFresh: Bool {
        guard let obtainedAt else { return false }
        return Date().timeIntervalSince(obtainedAt) < TimeInterval(max(expiresIn - 300, 0))
    }

    func grants(scope requiredScope: String) -> Bool {
        let grantedScopes = Set(scope.split(separator: " ").map(String.init))
        return grantedScopes.contains(requiredScope)
    }
}
