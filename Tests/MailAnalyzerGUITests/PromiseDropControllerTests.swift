import AppKit
import XCTest
@testable import MailAnalyzerGUI
@testable import MailAnalyzerGUICore

// Integration tests for the poll → reducer → outcome plumbing with a real
// temp directory. Real NSFilePromiseReceivers need a live drag session, so
// these run with zero receivers (expected clamps to 1) and files written
// directly into the drop directory — exactly the path Mail exercises when
// its reader block never fires.
@MainActor
final class PromiseDropControllerTests: XCTestCase {
    private var tempBase: URL!

    override func setUp() {
        super.setUp()
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("mail-analyzer-gui-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempBase, tempBase.path.contains("mail-analyzer-gui-tests-") {
            try? FileManager.default.removeItem(at: tempBase)
        }
        super.tearDown()
    }

    private let fastConfig = PromiseDropSession.Config(
        stableWindow: 0.2, quietWindow: 0.6, deadline: 3.0)

    private func waitForOutcome(
        _ controller: PromiseDropController,
        received: @escaping () -> PromiseDropController.Outcome?,
        timeout: TimeInterval = 10
    ) async throws -> PromiseDropController.Outcome {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while received() == nil {
            if ContinuousClock.now >= deadline {
                XCTFail("no outcome within \(timeout)s")
                throw XCTSkip("timed out")
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return received()!
    }

    func testFilesAppearingInDropDirectoryAreDelivered() async throws {
        var outcome: PromiseDropController.Outcome?
        let controller = PromiseDropController(
            tempBase: tempBase, config: fastConfig) { outcome = $0 }
        controller.start(receivers: [])

        let dir = controller.dropDirectory.appendingPathComponent("r0", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("mail body".utf8).write(to: dir.appendingPathComponent("a.eml"))

        let result = try await waitForOutcome(controller, received: { outcome })
        guard case .files(let urls, let warning) = result else {
            return XCTFail("expected files outcome, got \(result)")
        }
        XCTAssertEqual(urls.map(\.lastPathComponent), ["a.eml"])
        XCTAssertNil(warning)
    }

    func testMultipleFilesWithUnderCountedHintAllArrive() async throws {
        var outcome: PromiseDropController.Outcome?
        let controller = PromiseDropController(
            tempBase: tempBase, config: fastConfig) { outcome = $0 }
        controller.start(receivers: [])

        let dir = controller.dropDirectory.appendingPathComponent("r0", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Hint is 1 (zero receivers clamp), but three files land staggered.
        try Data("a".utf8).write(to: dir.appendingPathComponent("a.eml"))
        try await Task.sleep(nanoseconds: 150_000_000)
        try Data("b".utf8).write(to: dir.appendingPathComponent("b.eml"))
        try Data("c".utf8).write(to: dir.appendingPathComponent("c.eml"))

        let result = try await waitForOutcome(controller, received: { outcome })
        guard case .files(let urls, _) = result else {
            return XCTFail("expected files outcome, got \(result)")
        }
        XCTAssertEqual(urls.map(\.lastPathComponent).sorted(), ["a.eml", "b.eml", "c.eml"])
    }

    func testNoFilesFailsAtDeadlineNeverSilent() async throws {
        var outcome: PromiseDropController.Outcome?
        let controller = PromiseDropController(
            tempBase: tempBase, config: fastConfig) { outcome = $0 }
        controller.start(receivers: [])

        let result = try await waitForOutcome(controller, received: { outcome }, timeout: 8)
        guard case .failure(let message) = result else {
            return XCTFail("expected failure outcome, got \(result)")
        }
        XCTAssertTrue(message.contains("No files were received"))
    }

    // The legacy-promise path (Mail multi-message): exact name count →
    // completion on stability alone, well inside the quiet window.
    func testLegacyPathDeliversExactCountFast() async throws {
        var outcome: PromiseDropController.Outcome?
        let controller = PromiseDropController(
            tempBase: tempBase, config: fastConfig) { outcome = $0 }
        let destination = try controller.prepareLegacyDestination()
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        // The source (Mail) writes after namesOfPromisedFilesDropped.
        try Data("a".utf8).write(to: destination.appendingPathComponent("m1.eml"))
        try Data("b".utf8).write(to: destination.appendingPathComponent("m2.eml"))
        controller.startLegacy(expectedCount: 2)

        let start = ContinuousClock.now
        let result = try await waitForOutcome(controller, received: { outcome })
        let elapsed = start.duration(to: .now)
        guard case .files(let urls, let warning) = result else {
            return XCTFail("expected files outcome, got \(result)")
        }
        XCTAssertEqual(urls.map(\.lastPathComponent).sorted(), ["m1.eml", "m2.eml"])
        XCTAssertNil(warning)
        // Exact count completes on stability (0.2s) without the quiet
        // window: ~0.5s with poll granularity; the quiet path would need
        // ~1.0s. 0.75s discriminates with margin against jitter.
        XCTAssertLessThan(elapsed, .seconds(0.75))
    }

    func testLegacyPathShortfallWarnsViaQuietWindow() async throws {
        var outcome: PromiseDropController.Outcome?
        let controller = PromiseDropController(
            tempBase: tempBase, config: fastConfig) { outcome = $0 }
        let destination = try controller.prepareLegacyDestination()
        try Data("a".utf8).write(to: destination.appendingPathComponent("m1.eml"))
        controller.startLegacy(expectedCount: 3)

        let result = try await waitForOutcome(controller, received: { outcome })
        guard case .files(let urls, let warning) = result else {
            return XCTFail("expected files outcome, got \(result)")
        }
        XCTAssertEqual(urls.map(\.lastPathComponent), ["m1.eml"])
        XCTAssertEqual(warning, "Received 1 of 3 promised files.")
    }
}
