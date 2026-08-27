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
