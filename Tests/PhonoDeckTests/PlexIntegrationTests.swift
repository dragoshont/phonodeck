import XCTest
@testable import PhonoDeck

@MainActor
final class PlexIntegrationTests: XCTestCase {

    // MARK: Auth

    func testAuthURLContainsClientCodeAndProduct() {
        let url = PlexAuthClient.authURL(code: "WXYZ")
        let string = url.absoluteString
        XCTAssertTrue(string.hasPrefix("https://app.plex.tv/auth#?"))
        XCTAssertTrue(string.contains("code=WXYZ"))
        XCTAssertTrue(string.contains("clientID="))
        XCTAssertTrue(string.contains("product"))
    }

    func testPINDecoding() throws {
        let pending = try JSONDecoder().decode(PlexPIN.self, from: Data(#"{"id":123,"code":"WXYZ","authToken":null}"#.utf8))
        XCTAssertEqual(pending.id, 123)
        XCTAssertEqual(pending.code, "WXYZ")
        XCTAssertNil(pending.authToken)

        let approved = try JSONDecoder().decode(PlexPIN.self, from: Data(#"{"id":123,"code":"WXYZ","authToken":"TOKEN"}"#.utf8))
        XCTAssertEqual(approved.authToken, "TOKEN")
    }

    func testUserTierFromSubscription() throws {
        let pass = try JSONDecoder().decode(PlexUser.self, from: Data(#"{"username":"dragos","title":"Dragos","subscription":{"active":true}}"#.utf8))
        XCTAssertEqual(pass.tier, .premium)
        XCTAssertTrue(pass.hasPlexPass)
        XCTAssertEqual(pass.displayName, "Dragos")

        let free = try JSONDecoder().decode(PlexUser.self, from: Data(#"{"username":"x"}"#.utf8))
        XCTAssertEqual(free.tier, .free)
        XCTAssertFalse(free.hasPlexPass)
        XCTAssertEqual(free.displayName, "x")
    }

    // MARK: Server discovery

    func testBestConnectionPrefersSecureLocal() throws {
        let json = """
        {"name":"Home","provides":"server",
         "connections":[
           {"uri":"http://192.168.1.5:32400","local":true,"relay":false},
           {"uri":"https://192-168-1-5.abc.plex.direct:32400","local":true,"relay":false},
           {"uri":"https://relay.plex.direct:443","local":false,"relay":true}
         ]}
        """
        let resource = try JSONDecoder().decode(PlexResource.self, from: Data(json.utf8))
        // ATS-safe: never the plain-http one; prefers secure local plex.direct.
        XCTAssertEqual(resource.bestConnection, "https://192-168-1-5.abc.plex.direct:32400")
    }

    func testBestConnectionFallsBackToRelay() throws {
        let json = #"{"name":"Remote","provides":"server","connections":[{"uri":"https://relay.plex.direct:443","local":false,"relay":true}]}"#
        let resource = try JSONDecoder().decode(PlexResource.self, from: Data(json.utf8))
        XCTAssertEqual(resource.bestConnection, "https://relay.plex.direct:443")
    }

    func testBestConnectionRejectsAllPlainHTTPConnections() throws {
        let json = """
        {"name":"Insecure","provides":"server",
         "connections":[
           {"uri":"http://192.168.1.5:32400","local":true,"relay":false},
           {"uri":"http://remote.example:32400","local":false,"relay":false}
         ]}
        """
        let resource = try JSONDecoder().decode(PlexResource.self, from: Data(json.utf8))
        XCTAssertNil(resource.bestConnection)
    }

    // MARK: Library mapping (token-bearing native-stream URLs)

    func testTrackMappingBuildsPlayableURL() throws {
        let json = """
        {"MediaContainer":{"Metadata":[
          {"ratingKey":"1001","type":"track","title":"Neon Skyline","grandparentTitle":"The Midnight","parentTitle":"Monsters","duration":215000,"year":2019,"thumb":"/library/metadata/1001/thumb/123",
           "Media":[{"Part":[{"key":"/library/parts/5001/file.flac","container":"flac"}]}]}
        ]}}
        """
        let response = try JSONDecoder().decode(PlexMetadataResponse.self, from: Data(json.utf8))
        let tracks = (response.mediaContainer.metadata ?? []).compactMap {
            $0.toMusicTrack(baseURL: "https://srv.plex.direct:32400", token: "TKN")
        }
        XCTAssertEqual(tracks.count, 1)
        let track = tracks[0]
        XCTAssertEqual(track.id, MusicProviderEntityID(source: .plex, rawValue: "1001"))
        XCTAssertEqual(track.title, "Neon Skyline")
        XCTAssertEqual(track.artistName, "The Midnight")
        XCTAssertEqual(track.albumTitle, "Monsters")
        XCTAssertEqual(track.durationSeconds, 215.0)
        XCTAssertEqual(track.releaseYear, "2019")
        XCTAssertEqual(track.source, .plex)
        XCTAssertEqual(track.sourceURL?.absoluteString,
                       "https://srv.plex.direct:32400/library/parts/5001/file.flac?X-Plex-Token=TKN")
        XCTAssertEqual(track.artworkURL?.absoluteString,
                       "https://srv.plex.direct:32400/library/metadata/1001/thumb/123?X-Plex-Token=TKN")
        XCTAssertEqual(RedactedURL.string(track.sourceURL!),
                   "https://srv.plex.direct:32400/library/parts/5001/file.flac?X-Plex-Token=REDACTED")
        XCTAssertTrue(RedactedURL.containsSensitiveQuery(track.sourceURL!))

        // The adapter turns that into a native-stream plan.
        let plan = PlexAdapter().playbackPlan(for: track)
        guard case let .nativeStream(url) = plan else { return XCTFail("expected native stream") }
        XCTAssertEqual(url, track.sourceURL)
        XCTAssertEqual(plan.policy, .nativeStream)
    }

    func testTrackWithoutPartIsSkipped() throws {
        let json = #"{"MediaContainer":{"Metadata":[{"ratingKey":"2","type":"track","title":"No Part"}]}}"#
        let response = try JSONDecoder().decode(PlexMetadataResponse.self, from: Data(json.utf8))
        let tracks = (response.mediaContainer.metadata ?? []).compactMap {
            $0.toMusicTrack(baseURL: "https://x", token: "t")
        }
        XCTAssertTrue(tracks.isEmpty)
    }

    func testMusicSectionsFilter() throws {
        let json = #"{"MediaContainer":{"Directory":[{"key":"1","title":"Music","type":"artist"},{"key":"2","title":"Movies","type":"movie"}]}}"#
        let response = try JSONDecoder().decode(PlexDirectoryResponse.self, from: Data(json.utf8))
        let music = (response.mediaContainer.directory ?? []).filter { $0.type == "artist" }
        XCTAssertEqual(music.count, 1)
        XCTAssertEqual(music[0].title, "Music")
        XCTAssertEqual(music[0].key, "1")
    }

    func testSearchHubsMapTracksAndAlbums() throws {
        let json = """
        {"MediaContainer":{"Hub":[
          {"type":"track","Metadata":[{"ratingKey":"10","type":"track","title":"S","grandparentTitle":"A","Media":[{"Part":[{"key":"/p/1"}]}]}]},
          {"type":"album","Metadata":[{"ratingKey":"20","type":"album","title":"Alb","parentTitle":"A","year":2020}]}
        ]}}
        """
        let response = try JSONDecoder().decode(PlexHubResponse.self, from: Data(json.utf8))
        var results = SourceSearchResults()
        for hub in response.mediaContainer.hub ?? [] {
            let meta = hub.metadata ?? []
            switch hub.type {
            case "track": results.tracks += meta.compactMap { $0.toMusicTrack(baseURL: "https://x", token: "t") }
            case "album": results.albums += meta.compactMap { $0.toMusicAlbum(baseURL: "https://x", token: "t") }
            default: break
            }
        }
        XCTAssertEqual(results.tracks.count, 1)
        XCTAssertEqual(results.albums.count, 1)
        XCTAssertEqual(results.albums[0].title, "Alb")
        XCTAssertEqual(results.albums[0].artistName, "A")
    }
}
