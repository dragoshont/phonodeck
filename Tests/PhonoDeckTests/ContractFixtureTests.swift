import XCTest

final class ContractFixtureTests: XCTestCase {
    func testPlaybackFixturesPreserveRouteOwnershipTruth() throws {
        let fixtures = try playbackFixtures()
        XCTAssertGreaterThanOrEqual(fixtures.count, 3)

        let native = try fixture(named: "native-plex-playing", in: fixtures)
        XCTAssertEqual(native.session.activeRouteDecision?.engine, "nativeAV")
        XCTAssertEqual(native.session.activeRouteDecision?.route, "native")
        XCTAssertEqual(native.session.activeRouteDecision?.requiresVisiblePlayer, false)
        XCTAssertEqual(native.session.activeRouteDecision?.canOwnSystemNowPlaying, true)
        XCTAssertNil(native.session.activeRouteDecision?.blockedState)

        let visible = try fixture(named: "visible-youtube-blocked", in: fixtures)
        XCTAssertEqual(visible.session.activeRouteDecision?.engine, "webEmbed")
        XCTAssertEqual(visible.session.activeRouteDecision?.route, "visibleWebPlayer")
        XCTAssertEqual(visible.session.activeRouteDecision?.requiresVisiblePlayer, true)
        XCTAssertEqual(visible.session.activeRouteDecision?.canOwnSystemNowPlaying, false)
        XCTAssertEqual(visible.session.activeRouteDecision?.blockedState?.kind, "unsupportedEngine")

        let blocked = try fixture(named: "missing-ownfiles-blocked", in: fixtures)
        XCTAssertEqual(blocked.session.activeRouteDecision?.engine, "none")
        XCTAssertEqual(blocked.session.activeRouteDecision?.route, "blocked")
        XCTAssertEqual(blocked.session.activeRouteDecision?.canOwnSystemNowPlaying, false)
        XCTAssertEqual(blocked.session.activeRouteDecision?.blockedState?.kind, "missingMediaURL")
    }

    func testProviderPolicyMatchesExpectedSystemOwnership() throws {
        let policyURL = repoRoot().appendingPathComponent("contracts/provider-policy.json")
        let policy = try JSONDecoder().decode(ProviderPolicyFixture.self, from: Data(contentsOf: policyURL))

        XCTAssertEqual(Set(policy.sources.keys), ["youtubeMusic", "youtube", "plex", "spotify", "ownFiles"])
        XCTAssertEqual(policy.sources["plex"]?.nativeSystemNowPlaying, true)
        XCTAssertEqual(policy.sources["ownFiles"]?.nativeSystemNowPlaying, true)
        XCTAssertEqual(policy.sources["youtubeMusic"]?.nativeSystemNowPlaying, false)
        XCTAssertEqual(policy.sources["youtube"]?.nativeSystemNowPlaying, false)
        XCTAssertEqual(policy.sources["spotify"]?.nativeSystemNowPlaying, false)
    }

    func testContractCheckScriptPasses() throws {
        try run("python3", ["scripts/contract-check.py"])
    }

    private func playbackFixtures() throws -> [String: PlaybackSessionFixture] {
        let fixturesDirectory = repoRoot().appendingPathComponent("contracts/fixtures/playback")
        let files = try FileManager.default.contentsOfDirectory(at: fixturesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try Dictionary(uniqueKeysWithValues: files.map { file in
            let name = file.deletingPathExtension().lastPathComponent
            let fixture = try JSONDecoder().decode(PlaybackSessionFixture.self, from: Data(contentsOf: file))
            return (name, fixture)
        })
    }

    private func fixture(named name: String, in fixtures: [String: PlaybackSessionFixture]) throws -> PlaybackSessionFixture {
        try XCTUnwrap(fixtures[name], "Missing fixture \(name)")
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.currentDirectoryURL = repoRoot()
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct PlaybackSessionFixture: Decodable {
    let version: Int
    let session: Session

    struct Session: Decodable {
        let state: State
        let queue: Queue
        let activeRouteDecision: RouteDecision?
    }

    struct State: Decodable {
        let kind: String
        let currentItemID: String?
        let elapsedSeconds: Double?
        let durationSeconds: Double?
        let reason: String?
    }

    struct Queue: Decodable {
        let items: [Item]
        let currentIndex: Int?
        let repeatMode: String
        let shuffleEnabled: Bool
    }

    struct Item: Decodable {
        let id: String
        let track: Track
        let routeDecision: RouteDecision
    }

    struct Track: Decodable {
        let id: String
        let title: String
        let artist: String
        let album: String?
        let source: String
        let durationSeconds: Double?
    }

    struct RouteDecision: Decodable {
        let route: String
        let engine: String
        let plan: Plan
        let systemIntegration: SystemIntegration
        let requiresVisiblePlayer: Bool
        let canOwnSystemNowPlaying: Bool
        let blockedState: BlockedState?
    }

    struct Plan: Decodable {
        let kind: String
        let policy: String
        let provider: String?
        let url: String?
        let contentID: String?
        let reason: String?
    }

    struct SystemIntegration: Decodable {
        let kind: String
        let canOwnSystemNowPlaying: Bool
        let reason: String?
    }

    struct BlockedState: Decodable {
        let kind: String
        let reason: String
        let source: String?
        let trackID: String?
        let engine: String?
    }
}

private struct ProviderPolicyFixture: Decodable {
    let version: Int
    let sources: [String: Source]

    struct Source: Decodable {
        let metadata: String
        let playback: String
        let downloads: String
        let nativeSystemNowPlaying: Bool
    }
}
