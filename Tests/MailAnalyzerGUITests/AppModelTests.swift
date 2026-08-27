import XCTest
@testable import MailAnalyzerGUI
@testable import MailAnalyzerGUICore

@MainActor
final class AppModelTests: XCTestCase {
    private let tempBase = URL(fileURLWithPath: "/tmp/mail-analyzer-gui-drop", isDirectory: true)

    private func sampleResult(category: String = "safe") -> AnalysisResult {
        AnalysisResult(
            sourceFile: "/tmp/a.eml", hash: "h",
            judgment: Judgment(isSuspicious: false, category: category, confidence: 0.9))
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while !condition() {
            if ContinuousClock.now >= deadline {
                return XCTFail("condition not met within \(timeout)s")
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testAnalysisRunsStrictlySequentially() async throws {
        actor Gauge {
            var current = 0
            var peak = 0
            func enter() { current += 1; peak = max(peak, current) }
            func exit() { current -= 1 }
        }
        let gauge = Gauge()
        let model = AppModel(
            runner: { [sample = sampleResult()] _, _ in
                await gauge.enter()
                try? await Task.sleep(nanoseconds: 50_000_000)
                await gauge.exit()
                return .success(sample)
            },
            dropTempBase: tempBase, deleteFile: { _ in })

        model.handleDropped(paths: ["/drop/a.eml", "/drop/b.eml"], promiseTemp: false)
        model.handleDropped(paths: ["/drop/c.eml"], promiseTemp: false)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }
        let peak = await gauge.peak
        XCTAssertEqual(peak, 1, "analyses must never overlap")
    }

    func testNewEntriesArePrependedInBatchOrder() async throws {
        let model = AppModel(
            runner: { [sample = sampleResult()] _, _ in .success(sample) },
            dropTempBase: tempBase, deleteFile: { _ in })
        model.handleDropped(paths: ["/drop/a.eml", "/drop/b.eml"], promiseTemp: false)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }
        model.handleDropped(paths: ["/drop/c.eml"], promiseTemp: false)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }
        XCTAssertEqual(model.entries.map(\.fileName), ["c.eml", "a.eml", "b.eml"])
    }

    func testFailureBecomesErrorState() async throws {
        let model = AppModel(
            runner: { _, _ in .failure(AnalyzerFailure("Analyzer returned empty output")) },
            dropTempBase: tempBase, deleteFile: { _ in })
        model.handleDropped(paths: ["/drop/a.eml"], promiseTemp: false)
        try await waitUntil {
            if case .error = model.entries.first?.state { return true }
            return false
        }
        XCTAssertEqual(model.entries.first?.state, .error("Analyzer returned empty output"))
    }

    func testRejectedExtensionsSurfaceNoticeAndAreNotQueued() {
        let model = AppModel(
            runner: { _, _ in .failure(AnalyzerFailure("unused")) },
            dropTempBase: tempBase, deleteFile: { _ in })
        model.handleDropped(paths: ["/drop/a.txt", "/drop/b.png"], promiseTemp: false)
        XCTAssertTrue(model.entries.isEmpty)
        XCTAssertNotNil(model.notice)
        XCTAssertTrue(model.notice!.contains("2"))
    }

    func testClearKeepsOnlyAnalyzingEntries() async throws {
        // First entry blocks in the runner (analyzing); the rest stay pending.
        let gate = AsyncStream<Void>.makeStream()
        var gateIterator = gate.stream.makeAsyncIterator()
        let model = AppModel(
            runner: { [sample = sampleResult()] _, _ in
                _ = await gateIterator.next()
                return .success(sample)
            },
            dropTempBase: tempBase, deleteFile: { _ in })
        model.handleDropped(paths: ["/drop/a.eml", "/drop/b.eml", "/drop/c.eml"], promiseTemp: false)
        try await waitUntil {
            if case .analyzing = model.entries.first(where: { $0.fileName == "a.eml" })?.state { return true }
            return false
        }
        model.clear()
        XCTAssertEqual(model.entries.map(\.fileName), ["a.eml"], "only the analyzing entry survives Clear")
        gate.continuation.yield()
        gate.continuation.finish()
        try await waitUntil { model.entries.first?.result != nil }
        // The cleared pending entries must not reappear.
        XCTAssertEqual(model.entries.map(\.fileName), ["a.eml"])
    }

    func testPromiseTempFilesAreDeletedOnlyInsideTempBase() async throws {
        var deleted: [String] = []
        let inside = tempBase.appendingPathComponent("u1/r0/a.eml").path
        let outside = "/Users/someone/Mail/b.eml"
        let model = AppModel(
            runner: { [sample = sampleResult()] _, _ in .success(sample) },
            dropTempBase: tempBase,
            deleteFile: { deleted.append($0.path) })
        model.handleDropped(paths: [inside, outside], promiseTemp: true)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }
        XCTAssertEqual(deleted, [inside], "the temp-base guard must protect files outside the drop dir")
    }

    func testFinderDropsAreNeverDeleted() async throws {
        var deleted: [String] = []
        let model = AppModel(
            runner: { [sample = sampleResult()] _, _ in .success(sample) },
            dropTempBase: tempBase,
            deleteFile: { deleted.append($0.path) })
        model.handleDropped(paths: [tempBase.appendingPathComponent("x.eml").path], promiseTemp: false)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }
        XCTAssertEqual(deleted, [])
    }

    func testExportCopiesListOrderJSONToPasteboard() async throws {
        let model = AppModel(
            runner: { _, url in
                .success(AnalysisResult(
                    sourceFile: url.path, hash: "h",
                    judgment: Judgment(isSuspicious: false, category: "safe", confidence: 1)))
            },
            dropTempBase: tempBase, deleteFile: { _ in })
        model.handleDropped(paths: ["/drop/a.eml", "/drop/b.eml"], promiseTemp: false)
        try await waitUntil { model.entries.allSatisfy { $0.result != nil } }

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("mail-analyzer-gui-tests"))
        model.exportJSON(pasteboard: pasteboard)
        let json = try XCTUnwrap(pasteboard.string(forType: .string))
        let decoded = try JSONDecoder().decode([AnalysisResult].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.map(\.sourceFile), ["/drop/a.eml", "/drop/b.eml"])
        XCTAssertEqual(model.exportMessage, L("JSON copied to clipboard."))
    }

    func testToggleExpanded() {
        let model = AppModel(
            runner: { _, _ in .failure(AnalyzerFailure("unused")) },
            dropTempBase: tempBase, deleteFile: { _ in })
        let id = UUID()
        model.toggleExpanded(id)
        XCTAssertTrue(model.expanded.contains(id))
        model.toggleExpanded(id)
        XCTAssertFalse(model.expanded.contains(id))
    }
}
