import AppKit
import SwiftUI

/// The real drop target, mounted as the root view's background so the whole
/// window accepts drags (legacy behavior — the visible dashed box is only a
/// hint). Draws nothing; highlight state is reported out to SwiftUI.
@MainActor
final class DropView: NSView {
    var onHighlight: (Bool) -> Void = { _ in }
    var onFileURLs: ([URL]) -> Void = { _ in }
    var onFilePromises: ([NSFilePromiseReceiver]) -> Void = { _ in }
    /// Old-protocol promise drop; must resolve inside performDragOperation
    /// (namesOfPromisedFilesDropped). Returns whether the drop was taken.
    var onLegacyPromise: (NSDraggingInfo) -> Bool = { _ in false }

    /// The pre-10.12 promise protocol. Measured against real Mail drags
    /// (2026-08): a multi-message drag offers ONLY this type — the modern
    /// NSFilePromiseReceiver types vanish from the pasteboard entirely.
    static let legacyPromiseType = NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // All drop paths in one native view — the legacy split (Tauri
        // DragDrop for Finder + an ObjC overlay for promises) is gone.
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map {
            NSPasteboard.PasteboardType($0)
        }
        registerForDraggedTypes([.fileURL, Self.legacyPromiseType] + promiseTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func hasFilePromises(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSFilePromiseReceiver.self], options: [:])
    }

    private func hasLegacyPromise(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.types?.contains(Self.legacyPromiseType) ?? false
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFilePromises(sender) || hasLegacyPromise(sender)
            || !fileURLs(from: sender).isEmpty else { return [] }
        onHighlight(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHighlight(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onHighlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onHighlight(false)
        // Promise-first, matching the legacy overlay's precedence. Within
        // promises, old-protocol first: it carries the exact promised-name
        // count (fast, no quiet-window wait) and it is the only protocol
        // Mail offers for multi-message drags. Single-message Mail drags
        // offer both, so this path serves them too.
        if hasLegacyPromise(sender) {
            if onLegacyPromise(sender) { return true }
            // Source refused to promise names — fall through to whatever
            // else is on the pasteboard.
        }
        if hasFilePromises(sender) {
            let receivers = (sender.draggingPasteboard.readObjects(
                forClasses: [NSFilePromiseReceiver.self],
                options: [:]) as? [NSFilePromiseReceiver]) ?? []
            if !receivers.isEmpty {
                onFilePromises(receivers)
                return true
            }
        }
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onFileURLs(urls)
        return true
    }
}

/// Bridges DropView under the SwiftUI hierarchy. NSHostingView content does
/// not register drag types, so AppKit routes window-wide drags to this
/// background view.
struct DropHostView: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeNSView(context: Context) -> DropView {
        let view = DropView()
        wire(view)
        return view
    }

    func updateNSView(_ nsView: DropView, context: Context) {
        wire(nsView)
    }

    private func wire(_ view: DropView) {
        let model = self.model
        view.onHighlight = { model.isDropTargeted = $0 }
        view.onFileURLs = { urls in
            model.handleDropped(paths: urls.map(\.path), promiseTemp: false)
        }
        view.onFilePromises = { receivers in
            model.handlePromiseDrop(receivers: receivers)
        }
        view.onLegacyPromise = { sender in
            model.handleLegacyPromiseDrop(sender)
        }
    }
}
