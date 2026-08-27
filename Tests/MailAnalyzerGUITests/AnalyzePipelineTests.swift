import XCTest
@testable import MailAnalyzerGUI
@testable import MailAnalyzerGUICore

// End-to-end pipeline test with a real stub analyzer script:
// validate → ProcessRunner → interpret, exactly as the GUI runs it.
final class AnalyzePipelineTests: XCTestCase {
    private var workDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mail-analyzer-gui-pipeline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let workDir, workDir.path.contains("mail-analyzer-gui-pipeline-") {
            try? FileManager.default.removeItem(at: workDir)
        }
        super.tearDown()
    }

    private func writeStub(_ script: String) throws -> URL {
        let url = workDir.appendingPathComponent("stub-analyzer")
        try ("#!/bin/sh\n" + script + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func testStubAnalyzerHappyPath() async throws {
        let json = """
        {"source_file":"/tmp/sample.eml","hash":"abc","to":null,
         "indicators":{"authentication":{"spf":"pass"},"sender":{},
                       "urls":null,"attachments":null,"routing":{"hop_count":2}},
         "judgment":{"is_suspicious":true,"category":"phishing","confidence":0.94,
                     "reasons":null,"tags":null}}
        """
        let jsonFile = workDir.appendingPathComponent("out.json")
        try json.write(to: jsonFile, atomically: true, encoding: .utf8)
        // Echoes the fixture only when the configured env var is present and
        // exactly one argument is given — asserting the invocation contract
        // from the outside.
        let stub = try writeStub("""
        [ "$#" -eq 1 ] || { echo "wrong argc" >&2; exit 64; }
        [ -n "$MAIL_ANALYZER_TEST_MARKER" ] || { echo "missing env" >&2; exit 65; }
        cat "\(jsonFile.path)"
        """)
        let eml = workDir.appendingPathComponent("mail.eml")
        try "From: x".write(to: eml, atomically: true, encoding: .utf8)

        let settings = AnalyzerSettings(
            binaryPath: stub.path,
            envVars: ["MAIL_ANALYZER_TEST_MARKER": "1", "EMPTY_STAYS_UNSET": ""])
        let result = await AppModel.analyze(settings: settings, url: eml)
        let analysis = try result.get()
        XCTAssertEqual(analysis.sourceFile, "/tmp/sample.eml")
        XCTAssertEqual(analysis.judgment.category, "phishing")
    }

    func testStubAnalyzerFailurePath() async throws {
        let stub = try writeStub("echo \"backend exploded\" >&2; exit 3")
        let eml = workDir.appendingPathComponent("mail.eml")
        try "From: x".write(to: eml, atomically: true, encoding: .utf8)

        let result = await AppModel.analyze(
            settings: AnalyzerSettings(binaryPath: stub.path, envVars: [:]), url: eml)
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(failure.message, "Analyzer exited with code 3\n\nStderr:\nbackend exploded")
    }

    func testUnconfiguredPathFailsBeforeSpawning() async {
        let result = await AppModel.analyze(
            settings: AnalyzerSettings(binaryPath: "", envVars: [:]),
            url: URL(fileURLWithPath: "/tmp/x.eml"))
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(
            failure.message,
            "Analyzer binary path is not configured. Please open Settings and set the path.")
    }
}
