import XCTest
@testable import MailAnalyzerGUICore

final class ProcessRunnerTests: XCTestCase {
    private func runShell(_ script: String, timeout: TimeInterval = 30) async -> Result<ProcessOutcome, AnalyzerFailure> {
        await ProcessRunner.run(
            binary: "/bin/sh", arguments: ["-c", script],
            environment: ProcessInfo.processInfo.environment,
            timeout: timeout)
    }

    func testSuccessCapturesStdout() async throws {
        let result = await runShell(#"printf '{"ok":true}'"#)
        let outcome = try result.get()
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.terminationDescription, "0")
        XCTAssertEqual(outcome.stdout, #"{"ok":true}"#)
        XCTAssertEqual(outcome.stderr, "")
    }

    func testNonZeroExitCapturesStderr() async throws {
        let result = await runShell("echo boom >&2; exit 3")
        let outcome = try result.get()
        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.terminationDescription, "3")
        XCTAssertEqual(outcome.stderr, "boom\n")
    }

    func testEnvironmentReachesChild() async throws {
        var env = ProcessInfo.processInfo.environment
        env["MAIL_ANALYZER_TEST_VAR"] = "injected"
        let result = await ProcessRunner.run(
            binary: "/bin/sh", arguments: ["-c", "printf %s \"$MAIL_ANALYZER_TEST_VAR\""],
            environment: env, timeout: 30)
        XCTAssertEqual(try result.get().stdout, "injected")
    }

    // Both pipes carrying more than a pipe buffer (64 KiB) at once must not
    // deadlock: the runner drains them before waiting on exit.
    func testLargeOutputOnBothPipesDoesNotDeadlock() async throws {
        let result = await runShell(
            #"/usr/bin/perl -e 'print "a" x 200000; print STDERR "b" x 200000'"#)
        let outcome = try result.get()
        XCTAssertEqual(outcome.stdout.count, 200_000)
        XCTAssertEqual(outcome.stderr.count, 200_000)
    }

    func testSpawnFailureIsReported() async {
        let result = await ProcessRunner.run(
            binary: "/nonexistent/mail-analyzer", arguments: ["/tmp/x.eml"],
            environment: [:], timeout: 5)
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertTrue(failure.message.hasPrefix("Failed to execute analyzer: "))
        XCTAssertTrue(failure.message.hasSuffix("Binary: /nonexistent/mail-analyzer"))
    }

    func testTimeoutTerminatesHungProcess() async {
        let start = ContinuousClock.now
        let result = await runShell("sleep 60", timeout: 1)
        let elapsed = start.duration(to: .now)
        guard case .failure(let failure) = result else { return XCTFail("expected timeout failure") }
        XCTAssertEqual(failure.message, "Analysis timed out after 1s. The analyzer process was terminated.")
        XCTAssertLessThan(elapsed, .seconds(5), "sh must die on SIGTERM well before the kill grace")
    }
}
