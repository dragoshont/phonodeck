import Foundation

struct YouTubeDataClient {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func currentChannel(accessToken: String) async throws -> YouTubeChannel? {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "mine", value: "true")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeDataError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw YouTubeDataError.requestFailed(httpResponse.statusCode, responseBody)
        }

        let decoded = try JSONDecoder().decode(YouTubeChannelsResponse.self, from: data)
        return decoded.items.first
    }
}

struct YouTubeChannelsResponse: Decodable, Equatable {
    let items: [YouTubeChannel]
}

struct YouTubeChannel: Decodable, Equatable {
    let id: String
    let snippet: Snippet

    struct Snippet: Decodable, Equatable {
        let title: String
    }
}

enum YouTubeDataError: LocalizedError, Equatable {
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "YouTube returned an invalid response."
        case .requestFailed(let statusCode, let body):
            "YouTube request failed (HTTP \(statusCode)): \(body)"
        }
    }
}
