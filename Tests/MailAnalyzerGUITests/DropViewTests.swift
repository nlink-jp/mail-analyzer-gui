import AppKit
import XCTest
@testable import MailAnalyzerGUI

/// Minimal NSDraggingInfo stand-in carrying a real pasteboard.
final class FakeDraggingInfo: NSObject, NSDraggingInfo {
    let pasteboard: NSPasteboard
    init(pasteboard: NSPasteboard) { self.pasteboard = pasteboard }

    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { pasteboard }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 0 }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination: Bool = false
    var numberOfValidItemsForDrop: Int = 0
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    func resetSpringLoading() {}
    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}

@MainActor
final class DropViewTests: XCTestCase {
    private func pasteboard(fileURLs: [URL]) -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("mail-analyzer-gui-tests-drag"))
        pb.clearContents()
        pb.writeObjects(fileURLs as [NSURL])
        return pb
    }

    func testRegistersForFileURLDrags() {
        let view = DropView()
        XCTAssertTrue(view.registeredDraggedTypes.contains(.fileURL))
    }

    func testFileURLDragEntersAndDrops() {
        let view = DropView()
        var highlights: [Bool] = []
        var received: [URL] = []
        view.onHighlight = { highlights.append($0) }
        view.onFileURLs = { received = $0 }

        let info = FakeDraggingInfo(pasteboard: pasteboard(
            fileURLs: [URL(fileURLWithPath: "/drop/a.eml"), URL(fileURLWithPath: "/drop/b.msg")]))
        XCTAssertEqual(view.draggingEntered(info), .copy)
        XCTAssertTrue(view.performDragOperation(info))
        XCTAssertEqual(received.map(\.path), ["/drop/a.eml", "/drop/b.msg"])
        XCTAssertEqual(highlights.first, true)
        XCTAssertEqual(highlights.last, false, "highlight must clear on drop")
    }

    // A Mail multi-message drag carries ONLY the old-protocol promise type
    // (measured 2026-08) — it must be accepted and routed to the legacy
    // handler.
    func testLegacyPromiseOnlyDragIsAcceptedAndRouted() {
        let view = DropView()
        XCTAssertTrue(view.registeredDraggedTypes.contains(DropView.legacyPromiseType))

        let pb = NSPasteboard(name: NSPasteboard.Name("mail-analyzer-gui-tests-legacy-promise"))
        pb.declareTypes([DropView.legacyPromiseType], owner: nil)
        pb.setString("promise", forType: DropView.legacyPromiseType)
        let info = FakeDraggingInfo(pasteboard: pb)

        var legacyCalls = 0
        view.onLegacyPromise = { _ in legacyCalls += 1; return true }
        var urlCalls = 0
        view.onFileURLs = { _ in urlCalls += 1 }

        XCTAssertEqual(view.draggingEntered(info), .copy)
        XCTAssertTrue(view.performDragOperation(info))
        XCTAssertEqual(legacyCalls, 1)
        XCTAssertEqual(urlCalls, 0)
    }

    func testLegacyPromiseRefusalFallsThrough() {
        let view = DropView()
        let pb = NSPasteboard(name: NSPasteboard.Name("mail-analyzer-gui-tests-legacy-refused"))
        pb.declareTypes([DropView.legacyPromiseType], owner: nil)
        pb.setString("promise", forType: DropView.legacyPromiseType)
        let info = FakeDraggingInfo(pasteboard: pb)

        view.onLegacyPromise = { _ in false }
        // Nothing else on the pasteboard → the drop fails cleanly.
        XCTAssertFalse(view.performDragOperation(info))
    }

    func testNonFileDragIsRejected() {
        let view = DropView()
        let pb = NSPasteboard(name: NSPasteboard.Name("mail-analyzer-gui-tests-drag-text"))
        pb.clearContents()
        pb.setString("just text", forType: .string)
        let info = FakeDraggingInfo(pasteboard: pb)
        XCTAssertEqual(view.draggingEntered(info), [])
        XCTAssertFalse(view.performDragOperation(info))
    }
}
