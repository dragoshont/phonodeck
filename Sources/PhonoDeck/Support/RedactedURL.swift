import Foundation

enum RedactedURL {
    private static let sensitiveQueryNames: Set<String> = [
        "x-plex-token",
        "access_token",
        "auth_token",
        "refresh_token",
        "client_secret",
        "id_token",
        "token",
        "secret",
        "code"
    ]

    private static func isSensitiveQueryName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sensitiveQueryNames.contains(normalized) || normalized.contains("token") || normalized.contains("secret")
    }

    static func string(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<invalid-url>"
        }
        components.queryItems = components.queryItems?.map { item in
            guard isSensitiveQueryName(item.name) else { return item }
            return URLQueryItem(name: item.name, value: "REDACTED")
        }
        return components.string ?? "<redacted-url>"
    }

    static func containsSensitiveQuery(_ url: URL) -> Bool {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return false }
        return items.contains { isSensitiveQueryName($0.name) && !($0.value ?? "").isEmpty }
    }
}