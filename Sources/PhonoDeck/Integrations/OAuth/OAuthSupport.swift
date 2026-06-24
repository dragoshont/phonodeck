import CryptoKit
import Foundation
import Security

// Shared OAuth primitives used by source adapters (Spotify today; Google has its
// own private copies). Portable, no UI dependency.

enum OAuthRandom {
    static func urlSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else { throw OAuthSupportError.randomGenerationFailed(status) }
        return Data(bytes).base64URLString()
    }
}

/// A PKCE verifier/challenge pair (RFC 7636, S256).
struct OAuthPKCE {
    let verifier: String
    let challenge: String

    init() throws {
        verifier = try OAuthRandom.urlSafeString(byteCount: 64)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        challenge = Data(digest).base64URLString()
    }
}

enum OAuthSupportError: LocalizedError, Equatable {
    case randomGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed(let status):
            "Secure random generation failed with status \(status)."
        }
    }
}

extension Data {
    /// Base64URL without padding (for PKCE + state).
    func base64URLString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
