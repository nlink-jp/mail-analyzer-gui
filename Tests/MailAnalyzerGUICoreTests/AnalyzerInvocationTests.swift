import XCTest
@testable import MailAnalyzerGUICore

final class AnalyzerInvocationTests: XCTestCase {
    // The three validation messages are legacy-verbatim contract text.
    func testValidateEmptyPath() {
        let msg = AnalyzerInvocation.validate(binaryPath: "", exists: { _ in true }, isFile: { _ in true })
        XCTAssertEqual(msg, "Analyzer binary path is not configured. Please open Settings and set the path.")
    }

    func testValidateMissingBinary() {
        let msg = AnalyzerInvocation.validate(
            binaryPath: "/opt/mail-analyzer", exists: { _ in false }, isFile: { _ in false })
        XCTAssertEqual(msg, "Analyzer binary not found at: /opt/mail-analyzer\nPlease check the path in Settings.")
    }

    func testValidateDirectoryPath() {
        let msg = AnalyzerInvocation.validate(
            binaryPath: "/opt", exists: { _ in true }, isFile: { _ in false })
        XCTAssertEqual(msg, "Path is not a file: /opt\nPlease set the path to the analyzer binary.")
    }

    func testValidateOK() {
        XCTAssertNil(AnalyzerInvocation.validate(
            binaryPath: "/usr/local/bin/mail-analyzer", exists: { _ in true }, isFile: { _ in true }))
    }

    func testEnvironmentSkipsEmptyValuesButKeepsParent() {
        let env = AnalyzerInvocation.environment(
            base: ["PATH": "/usr/bin", "MAIL_ANALYZER_LANG": "en"],
            envVars: ["MAIL_ANALYZER_PROJECT": "proj-1", "MAIL_ANALYZER_LANG": ""])
        XCTAssertEqual(env["PATH"], "/usr/bin")
        XCTAssertEqual(env["MAIL_ANALYZER_PROJECT"], "proj-1")
        // Empty value means "leave unset": the parent's value survives.
        XCTAssertEqual(env["MAIL_ANALYZER_LANG"], "en")
    }

    func testEnvironmentOverridesParentWithNonEmptyValue() {
        let env = AnalyzerInvocation.environment(
            base: ["MAIL_ANALYZER_MODEL": "old"],
            envVars: ["MAIL_ANALYZER_MODEL": "gemini-3-flash"])
        XCTAssertEqual(env["MAIL_ANALYZER_MODEL"], "gemini-3-flash")
    }

    func testInterpretNonZeroExitWithStderr() {
        let result = AnalyzerInvocation.interpret(
            terminationDescription: "1", succeeded: false,
            stdout: "partial output\n", stderr: "config error\n")
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        let msg = failure.message
        XCTAssertEqual(msg, "Analyzer exited with code 1\n\nStderr:\nconfig error")
        XCTAssertFalse(msg.contains("Output:"), "stdout must be suppressed when stderr is non-empty")
    }

    func testInterpretNonZeroExitWithStdoutOnly() {
        let result = AnalyzerInvocation.interpret(
            terminationDescription: "2", succeeded: false,
            stdout: "diagnostic text\n", stderr: "")
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        let msg = failure.message
        XCTAssertEqual(msg, "Analyzer exited with code 2\n\nOutput:\ndiagnostic text")
    }

    func testInterpretEmptyOutput() {
        let result = AnalyzerInvocation.interpret(
            terminationDescription: "0", succeeded: true, stdout: "  \n", stderr: "")
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        let msg = failure.message
        XCTAssertEqual(msg, "Analyzer returned empty output")
    }

    func testInterpretValidJSON() throws {
        let json = try String(decoding: fixtureData("minimal"), as: UTF8.self)
        let result = AnalyzerInvocation.interpret(
            terminationDescription: "0", succeeded: true, stdout: json, stderr: "")
        guard case .success(let analysis) = result else { return XCTFail("expected success") }
        XCTAssertEqual(analysis.sourceFile, "/tmp/minimal.eml")
    }

    // Legacy Rust sliced the first 500 *bytes* and panicked when the boundary
    // fell inside a multibyte character. prefix(500) must not crash and must
    // keep Characters intact.
    func testInterpretParseErrorTruncatesOnCharacterBoundary() {
        let garbage = String(repeating: "x", count: 499) + String(repeating: "日本語テキスト", count: 40)
        let result = AnalyzerInvocation.interpret(
            terminationDescription: "0", succeeded: true, stdout: garbage, stderr: "")
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        let msg = failure.message
        XCTAssertTrue(msg.hasPrefix("Failed to parse analyzer output: "))
        XCTAssertTrue(msg.contains("Raw output (first 500 chars):"))
        let raw = msg.components(separatedBy: "Raw output (first 500 chars):\n").last ?? ""
        XCTAssertEqual(raw.count, 500)
        XCTAssertTrue(raw.hasSuffix("日") || raw.hasSuffix("本") || raw.hasSuffix("語")
                      || raw.hasSuffix("テ") || raw.hasSuffix("キ") || raw.hasSuffix("ス") || raw.hasSuffix("ト"),
                      "truncation must end on a whole character")
    }
}
