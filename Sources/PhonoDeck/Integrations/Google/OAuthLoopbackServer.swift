import Foundation
import Darwin

final class OAuthLoopbackServer: @unchecked Sendable {
    let redirectURI: String

    private let callbackPath: String
    private let socketFileDescriptor: Int32
    private let lock = NSLock()
    private var continuation: CheckedContinuation<OAuthCallback, Error>?
    private var didComplete = false
    private var didCloseSocket = false
    private var pendingResult: Result<OAuthCallback, Error>?
    private var acceptTask: Task<Void, Never>?

    init(callbackPath: String, portRange: ClosedRange<Int> = 53100...53200) throws {
        self.callbackPath = callbackPath
        let selected = try Self.makeSocket(portRange: portRange)
        socketFileDescriptor = selected.socketFileDescriptor
        redirectURI = "http://127.0.0.1:\(selected.port)\(callbackPath)"
    }

    func start() throws {
        lock.lock()
        let shouldStart = acceptTask == nil
        if shouldStart {
            acceptTask = Task.detached(priority: .userInitiated) { [weak self] in
                self?.acceptOneConnection()
            }
        }
        lock.unlock()
    }

    func waitForCallback() async throws -> OAuthCallback {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let pendingResult: Result<OAuthCallback, Error>?
                lock.lock()
                pendingResult = self.pendingResult
                self.pendingResult = nil
                if pendingResult == nil {
                    self.continuation = continuation
                }
                lock.unlock()

                if let pendingResult {
                    switch pendingResult {
                    case .success(let callback):
                        continuation.resume(returning: callback)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancel()
        }
    }

    func cancel() {
        complete(with: .failure(CancellationError()))
    }

    private func acceptOneConnection() {
        var address = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let clientFileDescriptor = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.accept(socketFileDescriptor, sockaddrPointer, &length)
            }
        }

        guard clientFileDescriptor >= 0 else {
            if errno != EBADF {
                complete(with: .failure(POSIXError(POSIXErrorCode(rawValue: errno) ?? .ECONNABORTED)))
            }
            return
        }

        handle(clientFileDescriptor: clientFileDescriptor)
    }

    private func handle(clientFileDescriptor: Int32) {
        defer {
            Darwin.close(clientFileDescriptor)
        }

        var noSigPipe: Int32 = 1
        setsockopt(clientFileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = recv(clientFileDescriptor, &buffer, buffer.count, 0)
        guard bytesRead > 0 else {
            complete(with: .failure(GoogleOAuthError.invalidCallbackRequest))
            return
        }

        guard let request = String(data: Data(buffer.prefix(bytesRead)), encoding: .utf8) else {
            complete(with: .failure(GoogleOAuthError.invalidCallbackRequest))
            return
        }

        do {
            let callback = try Self.parseCallback(request: request, callbackPath: callbackPath)
            sendResponse(clientFileDescriptor: clientFileDescriptor, success: callback.error == nil)
            complete(with: .success(callback))
        } catch {
            sendResponse(clientFileDescriptor: clientFileDescriptor, success: false)
            complete(with: .failure(error))
        }
    }

    static func parseCallback(request: String, callbackPath: String) throws -> OAuthCallback {
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

    private func sendResponse(clientFileDescriptor: Int32, success: Bool) {
        let title = success ? "PhonoDeck connected" : "PhonoDeck connection failed"
        let body = "<!doctype html><html><head><title>\(title)</title></head><body><h1>\(title)</h1><p>You can return to PhonoDeck.</p></body></html>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        let bytes = [UInt8](response.utf8)
        bytes.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            var totalSent = 0
            while totalSent < bytes.count {
                let sent = send(clientFileDescriptor, baseAddress.advanced(by: totalSent), bytes.count - totalSent, 0)
                guard sent > 0 else { return }
                totalSent += sent
            }
        }
    }

    private func complete(with result: Result<OAuthCallback, Error>) {
        let continuation: CheckedContinuation<OAuthCallback, Error>?

        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        continuation = self.continuation
        self.continuation = nil
        if continuation == nil {
            pendingResult = result
        }
        lock.unlock()

        closeServerSocket()

        if let continuation {
            switch result {
            case .success(let callback):
                continuation.resume(returning: callback)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    private func closeServerSocket() {
        lock.lock()
        guard !didCloseSocket else {
            lock.unlock()
            return
        }
        didCloseSocket = true
        lock.unlock()

        Darwin.close(socketFileDescriptor)
    }

    private static func makeSocket(portRange: ClosedRange<Int>) throws -> (socketFileDescriptor: Int32, port: UInt16) {
        for port in portRange {
            let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
            guard socketFileDescriptor >= 0 else { continue }

            var reuseAddress: Int32 = 1
            setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size))

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(port).bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

            let didBind = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    Darwin.bind(socketFileDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard didBind == 0 else {
                Darwin.close(socketFileDescriptor)
                continue
            }

            guard listen(socketFileDescriptor, 1) == 0 else {
                Darwin.close(socketFileDescriptor)
                continue
            }

            return (socketFileDescriptor, UInt16(port))
        }
        throw GoogleOAuthError.noAvailableLoopbackPort
    }

    deinit {
        closeServerSocket()
    }
}

struct OAuthCallback: Equatable {
    let code: String?
    let state: String?
    let error: String?
}
