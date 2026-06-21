import XCTest
@testable import PhonoDeck

final class GoogleOAuthTests: XCTestCase {
    func testAuthorizeFailsBeforeBrowserWithoutClientSecret() async {
        let configuration = GoogleOAuthConfiguration(
            clientID: "client-id.apps.googleusercontent.com",
            clientSecret: nil,
            scopes: ["https://www.googleapis.com/auth/youtube.readonly"],
            redirectPath: "/oauth/google/callback"
        )
        let client = GoogleOAuthClient(configuration: configuration)

        do {
            _ = try await client.authorize()
            XCTFail("Authorization should require the local Desktop client secret before opening a browser.")
        } catch GoogleOAuthError.missingClientSecret {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthorizationURLContainsInstalledAppParameters() throws {
        let configuration = GoogleOAuthConfiguration(
            clientID: "client-id.apps.googleusercontent.com",
            clientSecret: "secret",
            scopes: ["https://www.googleapis.com/auth/youtube.readonly"],
            redirectPath: "/oauth/google/callback"
        )

        let url = try configuration.authorizationURL(
            redirectURI: "http://127.0.0.1:53100/oauth/google/callback",
            state: "state-value",
            codeChallenge: "challenge-value"
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(components?.scheme, "https")
        XCTAssertEqual(components?.host, "accounts.google.com")
        XCTAssertEqual(queryItems["access_type"], "offline")
        XCTAssertEqual(queryItems["client_id"], "client-id.apps.googleusercontent.com")
        XCTAssertEqual(queryItems["code_challenge"], "challenge-value")
        XCTAssertEqual(queryItems["code_challenge_method"], "S256")
        XCTAssertEqual(queryItems["prompt"], "consent")
        XCTAssertEqual(queryItems["redirect_uri"], "http://127.0.0.1:53100/oauth/google/callback")
        XCTAssertEqual(queryItems["response_type"], "code")
        XCTAssertEqual(queryItems["scope"], "https://www.googleapis.com/auth/youtube.readonly")
        XCTAssertEqual(queryItems["state"], "state-value")
    }

    func testLoopbackParserExtractsCodeAndState() throws {
        let request = "GET /oauth/google/callback?code=abc123&state=state-value HTTP/1.1\r\nHost: 127.0.0.1:53100\r\n\r\n"

        let callback = try OAuthLoopbackServer.parseCallback(
            request: request,
            callbackPath: "/oauth/google/callback"
        )

        XCTAssertEqual(callback.code, "abc123")
        XCTAssertEqual(callback.state, "state-value")
        XCTAssertNil(callback.error)
    }

    func testLoopbackParserRejectsWrongPath() {
        let request = "GET /wrong/path?code=abc123&state=state-value HTTP/1.1\r\nHost: 127.0.0.1:53100\r\n\r\n"

        XCTAssertThrowsError(
            try OAuthLoopbackServer.parseCallback(request: request, callbackPath: "/oauth/google/callback")
        ) { error in
            XCTAssertEqual(error as? GoogleOAuthError, .invalidCallbackRequest)
        }
    }

    func testLoopbackServerAcceptsCallbackRequestAfterStartReturns() async throws {
        let server = try OAuthLoopbackServer(callbackPath: "/oauth/google/callback")
        try server.start()

        async let callback = server.waitForCallback()
        let callbackURL = URL(string: "\(server.redirectURI)?code=abc123&state=state-value")!
        let (data, response) = try await URLSession.shared.data(from: callbackURL)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        let body = String(data: data, encoding: .utf8)
        let result = try await callback

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertTrue(body?.contains("PhonoDeck connected") == true)
        XCTAssertEqual(result.code, "abc123")
        XCTAssertEqual(result.state, "state-value")
        XCTAssertNil(result.error)
    }

    func testFormURLEncoderEscapesReservedCharacters() {
        let encoded = String(
            data: FormURLEncoder.encode(["code": "a+b&c=d", "redirect_uri": "http://127.0.0.1:53100/oauth/google/callback"]),
            encoding: .utf8
        )

        XCTAssertNotNil(encoded)
        XCTAssertTrue(encoded?.contains("code=a%2Bb%26c%3Dd") == true)
        XCTAssertTrue(encoded?.contains("redirect_uri=http://127.0.0.1:53100/oauth/google/callback") == true)
    }
}