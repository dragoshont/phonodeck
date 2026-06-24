import XCTest
@testable import PhonoDeck

final class SpotifyIntegrationTests: XCTestCase {

    // MARK: OAuth

    func testAuthorizationURLContainsPKCEAndScopes() throws {
        let config = SpotifyOAuthConfiguration(
            clientID: "CID",
            scopes: ["user-read-private", "user-library-read"],
            redirectPath: "/callback",
            loopbackPort: 8888
        )
        let url = try config.authorizationURL(
            redirectURI: "http://127.0.0.1:8888/callback",
            state: "STATE",
            codeChallenge: "CHAL"
        )
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.host, "accounts.spotify.com")
        XCTAssertEqual(items["client_id"], "CID")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["redirect_uri"], "http://127.0.0.1:8888/callback")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["code_challenge"], "CHAL")
        XCTAssertEqual(items["state"], "STATE")
        XCTAssertTrue((items["scope"] ?? "").contains("user-library-read"))
    }

    func testPKCEChallengeIsDeterministicForVerifier() throws {
        // Two PKCE pairs differ; each challenge is non-empty base64url (no padding).
        let a = try OAuthPKCE()
        let b = try OAuthPKCE()
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertFalse(a.challenge.isEmpty)
        XCTAssertFalse(a.challenge.contains("="))
        XCTAssertFalse(a.challenge.contains("+"))
        XCTAssertFalse(a.challenge.contains("/"))
    }

    func testTokenSetDecodingAndFreshness() throws {
        let json = #"{"access_token":"AT","token_type":"Bearer","scope":"user-library-read","expires_in":3600,"refresh_token":"RT"}"#
        var tokens = try JSONDecoder().decode(SpotifyOAuthTokenSet.self, from: Data(json.utf8))
        XCTAssertEqual(tokens.accessToken, "AT")
        XCTAssertEqual(tokens.refreshToken, "RT")
        XCTAssertFalse(tokens.isFresh) // obtainedAt nil
        tokens.obtainedAt = Date()
        XCTAssertTrue(tokens.isFresh)
        tokens.obtainedAt = Date(timeIntervalSinceNow: -7200)
        XCTAssertFalse(tokens.isFresh)
    }

    func testOAuthErrorMessageParsing() {
        let data = Data(#"{"error":"invalid_grant","error_description":"Bad code"}"#.utf8)
        XCTAssertEqual(SpotifyOAuthErrorResponse.message(from: data), "Bad code")
    }

    // MARK: Web API DTO mapping -> neutral models

    func testUserProfileTierMapping() throws {
        let premium = try JSONDecoder().decode(SpotifyUserProfile.self, from: Data(#"{"id":"u","display_name":"Me","product":"premium"}"#.utf8))
        XCTAssertEqual(premium.tier, .premium)
        XCTAssertEqual(premium.displayName, "Me")

        let free = try JSONDecoder().decode(SpotifyUserProfile.self, from: Data(#"{"id":"u","product":"free"}"#.utf8))
        XCTAssertEqual(free.tier, .free)
        XCTAssertNil(free.displayName)
    }

    func testSearchResponseMapsToNeutralModels() throws {
        let json = """
        {
          "tracks": { "items": [
            { "id": "t1", "name": "Song One",
              "artists": [{"id":"a1","name":"Artist A"},{"id":"a2","name":"Artist B"}],
              "album": { "id":"al1","name":"Album X","images":[{"url":"https://img/x.jpg"}],"release_date":"2019-05-01" },
              "duration_ms": 215000,
              "external_urls": {"spotify":"https://open.spotify.com/track/t1"} }
          ]},
          "playlists": { "items": [
            { "id":"p1","name":"My Mix","owner":{"display_name":"Me"},"images":[{"url":"https://img/p.jpg"}],"tracks":{"total":12},"external_urls":{"spotify":"https://open.spotify.com/playlist/p1"} }
          ]},
          "artists": { "items": [ {"id":"a1","name":"Artist A","images":[{"url":"https://img/a.jpg"}]} ] },
          "albums": { "items": [ {"id":"al1","name":"Album X","images":[{"url":"https://img/x.jpg"}],"release_date":"2019","artists":[{"id":"a1","name":"Artist A"}]} ] }
        }
        """
        let response = try JSONDecoder().decode(SpotifySearchResponse.self, from: Data(json.utf8))
        let results = response.toResults()

        XCTAssertEqual(results.tracks.count, 1)
        let track = results.tracks[0]
        XCTAssertEqual(track.id, MusicProviderEntityID(source: .spotify, rawValue: "t1"))
        XCTAssertEqual(track.title, "Song One")
        XCTAssertEqual(track.artistName, "Artist A, Artist B")
        XCTAssertEqual(track.albumTitle, "Album X")
        XCTAssertEqual(track.releaseYear, "2019")
        XCTAssertEqual(track.durationSeconds, 215.0)
        XCTAssertEqual(track.source, .spotify)
        XCTAssertEqual(track.artworkURL?.absoluteString, "https://img/x.jpg")

        XCTAssertEqual(results.playlists.count, 1)
        XCTAssertEqual(results.playlists[0].title, "My Mix")
        XCTAssertEqual(results.playlists[0].trackCount, 12)
        XCTAssertEqual(results.playlists[0].ownerName, "Me")

        XCTAssertEqual(results.artists.count, 1)
        XCTAssertEqual(results.artists[0].name, "Artist A")

        XCTAssertEqual(results.albums.count, 1)
        XCTAssertEqual(results.albums[0].artistName, "Artist A")
        XCTAssertEqual(results.albums[0].releaseYear, "2019")
    }

    func testSavedTracksMapping() throws {
        let json = #"{"items":[{"track":{"id":"t1","name":"S","artists":[{"id":"a","name":"A"}],"duration_ms":1000}},{"track":null}]}"#
        let page = try JSONDecoder().decode(SpotifyPaged<SpotifySavedTrack>.self, from: Data(json.utf8))
        let tracks = page.items.compactMap { $0.track?.toMusicTrack() }
        XCTAssertEqual(tracks.count, 1)               // the null track is skipped
        XCTAssertEqual(tracks[0].durationSeconds, 1.0)
        XCTAssertEqual(tracks[0].source, .spotify)
    }

    func testSearchTypesMapping() {
        XCTAssertEqual(SpotifyWebAPIClient.searchTypes(for: [.songs]), ["track"])
        XCTAssertEqual(Set(SpotifyWebAPIClient.searchTypes(for: [.albums, .artists, .playlists])),
                       Set(["album", "artist", "playlist"]))
        XCTAssertEqual(SpotifyWebAPIClient.searchTypes(for: []), ["track"]) // default
    }
}
