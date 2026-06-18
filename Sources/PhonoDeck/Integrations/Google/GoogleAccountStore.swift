import Foundation

struct GoogleAccountStore {
    private let keychain = KeychainStore(service: "ro.hont.phonodeck.google")
    private let tokenAccount = "youtube-oauth-tokens"

    func loadTokens() throws -> GoogleOAuthTokenSet? {
        guard let data = try keychain.load(account: tokenAccount) else { return nil }
        return try JSONDecoder().decode(GoogleOAuthTokenSet.self, from: data)
    }

    func save(tokens: GoogleOAuthTokenSet) throws {
        let data = try JSONEncoder().encode(tokens)
        try keychain.save(data, account: tokenAccount)
    }

    func disconnect() throws {
        try keychain.delete(account: tokenAccount)
    }
}
