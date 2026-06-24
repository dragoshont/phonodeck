import XCTest

final class ReleaseEngineeringTests: XCTestCase {
    func testReleaseScriptsAreSyntaxValid() throws {
        try run("bash", ["-n", "scripts/release-preflight.sh"])
        try run("bash", ["-n", "scripts/package-local.sh"])
    }

    func testMakefileExposesReleaseTargets() throws {
        let makefile = try String(contentsOf: repoRoot().appendingPathComponent("Makefile"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("release-preflight:"))
        XCTAssertTrue(makefile.contains("package-local:"))
        XCTAssertTrue(makefile.contains("CODE_SIGNING_ALLOWED=NO build"))
        XCTAssertTrue(makefile.contains("CODE_SIGNING_ALLOWED=NO test"))
    }

    func testReleaseDocumentationKeepsPhase10Boundaries() throws {
        let document = try String(contentsOf: repoRoot().appendingPathComponent("docs/deployment/macos-release.md"), encoding: .utf8)

        XCTAssertTrue(document.contains("Final live validation, release notes, legal/privacy publication, and go/no-go remain Phase 10."))
        XCTAssertTrue(document.contains("must not print Apple IDs, team IDs, certificate identities, API keys, app-specific passwords, OAuth secrets, or token values"))
        XCTAssertTrue(document.contains("GOOGLE_OAUTH_CLIENT_SECRET` empty"))
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