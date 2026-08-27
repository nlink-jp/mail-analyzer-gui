import XCTest
@testable import MailAnalyzerGUICore

// All timestamps are synthetic — no sleeps. Config: stable 0.5s, quiet 2.0s,
// deadline 15s (defaults).
final class PromiseDropSessionTests: XCTestCase {
    private func makeSession(expected: Int) -> PromiseDropSession {
        PromiseDropSession(expectedCount: expected, startedAt: 0)
    }

    func testReaderDeliveringAllExpectedCompletesImmediately() {
        var s = makeSession(expected: 2)
        XCTAssertEqual(s.handle(.readerDelivered("r0/a.eml", at: 0.1)), .continuePolling)
        let step = s.handle(.readerDelivered("r1/b.eml", at: 0.2))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml", "r1/b.eml"], warning: nil)))
    }

    func testSilentReaderCompletesAfterQuietWindow() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 1000], at: 0.3)), .continuePolling)
        // Stable but not yet quiet: still polling.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 1000], at: 1.0)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 1000], at: 2.4))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml"], warning: nil)))
    }

    func testGrowingFileDefersCompletion() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.25)), .continuePolling)
        // Size keeps changing → lastActivity keeps moving, no completion.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 5000], at: 2.5)), .continuePolling)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 9000], at: 4.0)), .continuePolling)
        // Stable now, but quiet window restarts from the last growth.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 9000], at: 5.0)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 9000], at: 6.1))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml"], warning: nil)))
    }

    // Mail multi-message: one receiver with empty fileNames → hint is 1,
    // but three files land. The quiet window must gather all three — never
    // complete early on "count reached".
    func testUnderCountedHintDeliversAllFiles() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.2)), .continuePolling)
        // First file already stable — completing here would lose b and c.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100, "r0/b.eml": 200], at: 1.0)), .continuePolling)
        XCTAssertEqual(
            s.handle(.snapshot(["r0/a.eml": 100, "r0/b.eml": 200, "r0/c.eml": 300], at: 1.5)),
            .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 100, "r0/b.eml": 200, "r0/c.eml": 300], at: 3.6))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml", "r0/b.eml", "r0/c.eml"], warning: nil)))
    }

    // The opposite: three promised, one arrives, drop goes quiet → partial
    // delivery with a warning.
    func testOverCountedHintDeliversPartialWithWarning() {
        var s = makeSession(expected: 3)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.2)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 100], at: 2.3))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml"], warning: "Received 1 of 3 promised files.")))
    }

    // Zero files at the deadline must FAIL loudly — the legacy implementation
    // stayed silent forever (leaked run loop, no event, no error).
    func testZeroFilesAtDeadlineFails() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.snapshot([:], at: 5.0)), .continuePolling)
        let step = s.handle(.snapshot([:], at: 15.0))
        guard case .finished(.failure(let msg)) = step else {
            return XCTFail("expected failure outcome, got \(step)")
        }
        XCTAssertTrue(msg.contains("No files were received from the drag source within 15s."))
        XCTAssertTrue(msg.contains("Try saving the message as .eml in Finder"))
    }

    func testReaderErrorsAppearInDeadlineFailure() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.readerFailed("promise read failed: disk full", at: 1.0)), .continuePolling)
        let step = s.handle(.snapshot([:], at: 15.5))
        guard case .finished(.failure(let msg)) = step else {
            return XCTFail("expected failure outcome, got \(step)")
        }
        XCTAssertTrue(msg.contains("promise read failed: disk full"))
    }

    // A file still being written at the hard deadline is delivered anyway,
    // with a warning.
    func testDeadlineWithUnstableFilesDeliversWithWarning() {
        var s = makeSession(expected: 1)
        var size: UInt64 = 0
        var step: PromiseDropSession.Step = .continuePolling
        var t = 0.25
        while t < 15.1 {
            size += 100
            step = s.handle(.snapshot(["r0/a.eml": size], at: t))
            if step != .continuePolling { break }
            t += 0.25
        }
        XCTAssertEqual(
            step,
            .finished(.files(["r0/a.eml"],
                             warning: "Timed out waiting for promised files; proceeding with 1 file(s).")))
    }

    func testEventsAfterCompletionAreIgnored() {
        var s = makeSession(expected: 1)
        _ = s.handle(.snapshot(["r0/a.eml": 100], at: 0.2))
        let finish = s.handle(.snapshot(["r0/a.eml": 100], at: 2.5))
        XCTAssertEqual(finish, .finished(.files(["r0/a.eml"], warning: nil)))
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100, "r0/late.eml": 5], at: 3.0)), .continuePolling)
        XCTAssertEqual(s.handle(.readerDelivered("r0/late.eml", at: 3.1)), .continuePolling)
    }

    func testDotFilesAreIgnored() {
        var s = makeSession(expected: 1)
        XCTAssertEqual(s.handle(.snapshot(["r0/.DS_Store": 10], at: 0.2)), .continuePolling)
        // Only the dot-file exists → treated as zero files; deadline fails.
        let step = s.handle(.snapshot(["r0/.DS_Store": 10], at: 15.2))
        guard case .finished(.failure) = step else {
            return XCTFail("dot-files must not count as received files, got \(step)")
        }
    }

    // Exact counts (legacy promise names) complete on stability alone — no
    // quiet-window wait. This is the Mail single-message latency fix.
    func testExactCountCompletesOnStabilityWithoutQuietWait() {
        var s = PromiseDropSession(expectedCount: 2, expectedIsExact: true, startedAt: 0)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100, "r0/b.eml": 200], at: 0.25)), .continuePolling)
        // 0.5s stability reached at 0.75 — quiet window (2.0s) NOT required.
        let step = s.handle(.snapshot(["r0/a.eml": 100, "r0/b.eml": 200], at: 0.75))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml", "r0/b.eml"], warning: nil)))
    }

    func testExactCountStillWaitsForAllFiles() {
        var s = PromiseDropSession(expectedCount: 3, expectedIsExact: true, startedAt: 0)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.25)), .continuePolling)
        // Stable but only 1 of 3 — must not complete early; quiet window
        // eventually delivers the shortfall with a warning.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.8)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 100], at: 2.4))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml"], warning: "Received 1 of 3 promised files.")))
    }

    func testExactCountWaitsForStability() {
        var s = PromiseDropSession(expectedCount: 1, expectedIsExact: true, startedAt: 0)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 100], at: 0.25)), .continuePolling)
        // Still growing at 0.5 → not stable → no completion.
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 900], at: 0.5)), .continuePolling)
        XCTAssertEqual(s.handle(.snapshot(["r0/a.eml": 900], at: 0.75)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 900], at: 1.0))
        XCTAssertEqual(step, .finished(.files(["r0/a.eml"], warning: nil)))
    }

    func testZeroExpectedIsTreatedAsOne() {
        var s = PromiseDropSession(expectedCount: 0, startedAt: 0)
        XCTAssertEqual(s.handle(.snapshot([:], at: 1.0)), .continuePolling)
        let step = s.handle(.snapshot(["r0/a.eml": 50], at: 1.5))
        XCTAssertEqual(step, .continuePolling)
        XCTAssertEqual(
            s.handle(.snapshot(["r0/a.eml": 50], at: 3.6)),
            .finished(.files(["r0/a.eml"], warning: nil)))
    }
}
