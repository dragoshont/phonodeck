import Foundation
import Network

final class OAuthLoopbackServer: @unchecked Sendable {
    let redirectURI: String

    private let callbackPath: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "PhonoDeck.OAuthLoopbackServer")
    private var continuation: CheckedContinuation<OAuthCallback, Error>?
    private var didComplete = false

    init(callbackPath: String) throws {
        self.callbackPath = callbackPath
        listener = try NWListener(using: .tcp, on: .any)
        guard let port = listener.port else {
            throw GoogleOAuthError.invalidAuthorizationURL
        }
        redirectURI = "http://127.0.0.1:\(port.rawValue)\(callbackPath)"
    }

    func start() throws {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.complete(with: .failure(error), connection: nil)
            }
        }
        listener.start(queue: queue)
    }

    func waitForCallback() async throws -> OAuthCallback {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.complete(with: .failure(error), connection: connection)
                return
            }
            guard let data, let request = String(data: data, encoding: .utf8) else {
                self.complete(with: .failure(GoogleOAuthError.invalidCallbackRequest), connection: connection)
                return
            }
            do {
                let callback = try self.parse(request: request)
                self.sendResponse(connection: connection, success: callback.error == nil)
                self.complete(with: .success(callback), connection: connection)
            } catch {
                self.sendResponse(connection: connection, success: false)
                self.complete(with: .failure(error), connection: connection)
            }
        }
    }

    private func parse(request: String) throws -> OAuthCallback {
        guard let requestLine = request.components(separatedBy: "\r\n").first else {
            throw GoogleOAuthError.invalidCallbackRequest
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            throw GoogleOAuthError.invalidCallbackRequest
        }
        let target = String(parts[1])
        guard target.hasPrefix(callbackPath) else {
            throw GoogleOAuthError.invalidCallbackRequest
        }

        let components = URLComponents(string: "http://127.0.0.1\(target)")
        let items = components?.queryItems ?? []
        return OAuthCallback(
            code: items.first(where: { $0.name == "code" })?.value,
            state: items.first(where: { $0.name == "state" })?.value,
            error: items.first(where: { $0.name == "error" })?.value
        )
    }

    private func sendResponse(connection: NWConnection, success: Bool) {
        let title = success ? "PhonoDeck connected" : "PhonoDeck connection failed"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!doctype html><html><head><title>\(title)</title></head><body><h1>\(title)</h1><p>You can return to PhonoDeck.</p></body></html>"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
    }

    private func complete(with result: Result<OAuthCallback, Error>, connection: NWConnection?) {
        guard !didComplete else {
            connection?.cancel()
            return
        }
        didComplete = true
        listener.cancel()
        connection?.cancel()

        switch result {
        case .success(let callback):
            continuation?.resume(returning: callback)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

struct OAuthCallback: Equatable {
    let code: String?
    let state: String?
    let error: String?
}
