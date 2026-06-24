import XCTest

final class ReleaseEngineeringTests: XCTestCase {
    func testReleaseScriptsAreSyntaxValid() throws {
        try run("bash", ["-n", "scripts/release-preflight.sh"])
        try run("bash", ["-n", "scripts/package-local.sh"])
        try run("python3", ["-m", "py_compile", "scripts/qa-evidence-status.py"])
        try run("python3", ["-m", "py_compile", "scripts/contract-check.py"])
    }

    func testMakefileExposesReleaseTargets() throws {
        let makefile = try String(contentsOf: repoRoot().appendingPathComponent("Makefile"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("release-preflight:"))
        XCTAssertTrue(makefile.contains("package-local:"))
        XCTAssertTrue(makefile.contains("qa-evidence:"))
        XCTAssertTrue(makefile.contains("contract-check:"))
        XCTAssertTrue(makefile.contains("CODE_SIGNING_ALLOWED=NO build"))
        XCTAssertTrue(makefile.contains("CODE_SIGNING_ALLOWED=NO test"))
    }

    func testQAEvidenceReportIsGeneratedAndHonestAboutReviewRows() throws {
        let output = try runCapturingOutput("python3", ["scripts/qa-evidence-status.py"])

        XCTAssertTrue(output.contains("Total rows: 550"))
        XCTAssertTrue(output.contains("needs-review:"))
        XCTAssertTrue(output.contains("manual-or-live-evidence:"))
        XCTAssertTrue(output.contains("Rows Requiring Review"))
        XCTAssertTrue(output.contains("keyboard".capitalized) || output.localizedCaseInsensitiveContains("keyboard"))
    }

    func testQAEvidenceClassifierFixtureCoversExpectedCategories() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fixture = temporaryDirectory.appendingPathComponent("matrix.md")
        try """
        | ID | P0 Test Case | Status | Evidence / Gap |
        |---|---|---|---|
        | FX-001 | Search works | PASS | Implemented in view model. |
        | FX-002 | Keyboard navigation works | PASS | Implemented in view model. |
        | FX-003 | Provider failure has tests | PASS | Added fixture tests. |
        | FX-004 | Albums feature complete | PASS | The album feature itself remains missing. |
        | FX-005 | Plain claim | PASS | Looks good. |
        | FX-006 | Broken path | FAIL | Missing. |
        """.write(to: fixture, atomically: true, encoding: .utf8)

        let output = try runCapturingOutput("python3", ["scripts/qa-evidence-status.py", fixture.path])

        XCTAssertTrue(output.contains("implemented-claim: 1"))
        XCTAssertTrue(output.contains("manual-or-live-evidence: 1"))
        XCTAssertTrue(output.contains("tested-evidence: 1"))
        XCTAssertTrue(output.contains("needs-review: 1"))
        XCTAssertTrue(output.contains("unclassified-pass: 1"))
        XCTAssertTrue(output.contains("fail: 1"))
        XCTAssertTrue(output.contains("FX-002"))
        XCTAssertTrue(output.contains("FX-004"))
        XCTAssertTrue(output.contains("FX-005"))
        XCTAssertTrue(output.contains("FX-006"))
    }

    func testReleaseDocumentationKeepsPhase10Boundaries() throws {
        let document = try String(contentsOf: repoRoot().appendingPathComponent("docs/deployment/macos-release.md"), encoding: .utf8)

        XCTAssertTrue(document.contains("Final live validation, release notes, legal/privacy publication, and go/no-go remain Phase 10."))
        XCTAssertTrue(document.contains("must not print Apple IDs, team IDs, certificate identities, API keys, app-specific passwords, OAuth secrets, or token values"))
        XCTAssertTrue(document.contains("GOOGLE_OAUTH_CLIENT_SECRET` empty"))
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        _ = try runProcess(executable, arguments)
    }

    private func runCapturingOutput(_ executable: String, _ arguments: [String]) throws -> String {
        try runProcess(executable, arguments)
    }

    private func runProcess(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.currentDirectoryURL = repoRoot()
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let outputString = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorString = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0)
        return outputString + errorString
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}