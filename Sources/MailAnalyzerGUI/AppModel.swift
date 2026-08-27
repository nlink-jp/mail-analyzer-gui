import AppKit
import Foundation
import MailAnalyzerGUICore

@MainActor
final class AppModel: ObservableObject {
    enum EntryState: Equatable {
        case pending
        case analyzing
        case done(AnalysisResult)
        case error(String)
    }

    struct MailEntry: Identifiable, Equatable {
        let id: UUID
        let fileName: String
        let url: URL
        let isPromiseTemp: Bool
        var state: EntryState

        var result: AnalysisResult? {
            if case .done(let r) = state { return r }
            return nil
        }
    }

    @Published private(set) var entries: [MailEntry] = []
    @Published var expanded: Set<UUID> = []
    @Published var notice: String?
    @Published var exportMessage: String?
    @Published var showSettings = false
    @Published var isDropTargeted = false

    typealias Runner = (AnalyzerSettings, URL) async -> Result<AnalysisResult, AnalyzerFailure>

    private let runner: Runner
    let defaults: UserDefaults
    private let deleteFile: (URL) -> Void
    /// Base directory for promise-drop temp files; the deletion guard —
    /// never remove anything outside it — is legacy behavior kept verbatim.
    nonisolated let dropTempBase: URL

    private struct QueueItem {
        let id: UUID
        let url: URL
        let isPromiseTemp: Bool
    }

    private var pendingQueue: [QueueItem] = []
    private var workerRunning = false
    private var noticeGeneration = 0
    /// Live promise-drop controllers, retained until they deliver their one
    /// outcome (deterministic teardown — the legacy WatchContext leaked).
    private var promiseControllers: [ObjectIdentifier: PromiseDropController] = [:]

    static let defaultDropTempBase = URL(
        fileURLWithPath: NSTemporaryDirectory(), isDirectory: true
    ).appendingPathComponent("mail-analyzer-gui-drop", isDirectory: true)

    init(
        runner: @escaping Runner = AppModel.analyze,
        defaults: UserDefaults = .standard,
        dropTempBase: URL = AppModel.defaultDropTempBase,
        deleteFile: @escaping (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }
    ) {
        self.runner = runner
        self.defaults = defaults
        self.dropTempBase = dropTempBase
        self.deleteFile = deleteFile
    }

    var hasResults: Bool { entries.contains { $0.result != nil } }

    // MARK: - Intake

    /// Entry point for both drop paths (Finder file URLs and resolved Apple
    /// Mail promises). Filters to .eml/.msg, prepends new entries (newest
    /// first — legacy order), and queues them for sequential analysis.
    func handleDropped(paths: [String], promiseTemp: Bool) {
        let (accepted, rejected) = DropFilter.partition(paths: paths)
        if !rejected.isEmpty {
            // The legacy app dropped these silently; surface a notice.
            showNotice(L("Ignored %d file(s) — only .eml / .msg are analyzed.", rejected.count))
        }
        guard !accepted.isEmpty else { return }

        var newEntries: [MailEntry] = []
        for path in accepted {
            let url = URL(fileURLWithPath: path)
            newEntries.append(MailEntry(
                id: UUID(),
                fileName: url.lastPathComponent,
                url: url,
                isPromiseTemp: promiseTemp,
                state: .pending))
        }
        entries.insert(contentsOf: newEntries, at: 0)
        pendingQueue.append(contentsOf: newEntries.map {
            QueueItem(id: $0.id, url: $0.url, isPromiseTemp: $0.isPromiseTemp)
        })
        ensureWorker()
    }

    func reportDropFailure(_ message: String) {
        showNotice(L("Drop failed: %@", message))
    }

    /// Entry point for modern file-promise drags (NSFilePromiseReceiver —
    /// Mail offers this for single-message drags only). Every drop gets its
    /// own controller and temp subdirectory; the outcome — success, partial,
    /// or failure — always reaches the UI (the legacy drop-error event was
    /// emitted into the void).
    func handlePromiseDrop(receivers: [NSFilePromiseReceiver]) {
        guard !receivers.isEmpty else { return }
        let controller = makeRetainedPromiseController()
        controller.start(receivers: receivers)
    }

    /// Entry point for old-protocol promise drags
    /// (`com.apple.pasteboard.promised-file-url` — the only thing Mail
    /// offers for multi-message drags; measured 2026-08). Must run inside
    /// `performDragOperation`: `namesOfPromisedFilesDropped` both asks the
    /// source to write into our directory and returns the exact promised
    /// names. Returns false when the source promises nothing.
    @discardableResult
    func handleLegacyPromiseDrop(_ sender: NSDraggingInfo) -> Bool {
        let controller = makeRetainedPromiseController()
        do {
            let destination = try controller.prepareLegacyDestination()
            // Deprecated since 10.13 but still the only API that keeps
            // Mail's multi-message promise; see AGENTS.md gotchas.
            let names = sender.namesOfPromisedFilesDropped(atDestination: destination) ?? []
            guard !names.isEmpty else {
                promiseControllers[ObjectIdentifier(controller)] = nil
                return false
            }
            controller.startLegacy(expectedCount: names.count)
            return true
        } catch {
            promiseControllers[ObjectIdentifier(controller)] = nil
            reportDropFailure(error.localizedDescription)
            return false
        }
    }

    private func makeRetainedPromiseController() -> PromiseDropController {
        var controllerID: ObjectIdentifier?
        let controller = PromiseDropController(tempBase: dropTempBase) { [weak self] outcome in
            guard let self else { return }
            if let id = controllerID {
                self.promiseControllers[id] = nil
            }
            switch outcome {
            case .files(let urls, let warning):
                if let warning {
                    self.showNotice(warning)
                }
                self.handleDropped(paths: urls.map(\.path), promiseTemp: true)
            case .failure(let message):
                self.reportDropFailure(message)
            }
        }
        let id = ObjectIdentifier(controller)
        controllerID = id
        promiseControllers[id] = controller
        return controller
    }

    /// Crash hygiene: drop directories older than a day are leftovers from a
    /// crashed session (a clean run deletes its files after analysis).
    /// Strictly scoped to our own temp namespace.
    nonisolated func sweepStaleDropDirectories(olderThan age: TimeInterval = 86_400) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dropTempBase,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])
        else { return }
        let cutoff = Date().addingTimeInterval(-age)
        for url in entries {
            guard let values = try? url.resourceValues(
                    forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff,
                  url.standardizedFileURL.path.hasPrefix(dropTempBase.standardizedFileURL.path)
            else { continue }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Sequential analysis worker

    private func ensureWorker() {
        guard !workerRunning else { return }
        workerRunning = true
        Task { [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        while !pendingQueue.isEmpty {
            let item = pendingQueue.removeFirst()
            guard entries.contains(where: { $0.id == item.id }) else {
                // Cleared while pending: skip the analysis entirely (the
                // legacy app analyzed it invisibly), but still clean up.
                removeTempFileIfNeeded(item)
                continue
            }
            setState(.analyzing, for: item.id)
            let settings = AnalyzerSettings.load(from: defaults)
            let result = await runner(settings, item.url)
            switch result {
            case .success(let analysis):
                setState(.done(analysis), for: item.id)
            case .failure(let failure):
                setState(.error(failure.message), for: item.id)
            }
            removeTempFileIfNeeded(item)
        }
        workerRunning = false
    }

    private func setState(_ state: EntryState, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].state = state
    }

    /// Fire-and-forget deletion of a promise temp file, guarded to the drop
    /// temp base so a Finder-dropped original can never be removed. Empty
    /// parent directories (r<i>/ and the drop's UUID dir) are pruned once
    /// their last file is gone.
    private func removeTempFileIfNeeded(_ item: QueueItem) {
        guard item.isPromiseTemp else { return }
        let base = dropTempBase.standardizedFileURL.path
        guard item.url.standardizedFileURL.path.hasPrefix(base) else { return }
        deleteFile(item.url)

        let fm = FileManager.default
        var dir = item.url.deletingLastPathComponent().standardizedFileURL
        while dir.path.hasPrefix(base), dir.path != base,
              let contents = try? fm.contentsOfDirectory(atPath: dir.path),
              contents.isEmpty {
            try? fm.removeItem(at: dir)
            dir = dir.deletingLastPathComponent().standardizedFileURL
        }
    }

    // MARK: - Toolbar actions

    /// Keep only entries that are currently analyzing (legacy Clear).
    /// Queued pending entries are also dropped from the queue — unlike the
    /// legacy app, which kept analyzing them invisibly.
    func clear() {
        let removedPending = pendingQueue.filter { item in
            entries.contains { $0.id == item.id && $0.state == .pending }
        }
        entries.removeAll { $0.state != .analyzing }
        pendingQueue.removeAll { item in !entries.contains { $0.id == item.id } }
        for item in removedPending {
            removeTempFileIfNeeded(item)
        }
        expanded = expanded.filter { id in entries.contains { $0.id == id } }
    }

    /// Export all finished results (list order) as pretty-printed JSON to
    /// the clipboard — legacy behavior, clipboard not file.
    func exportJSON(pasteboard: NSPasteboard = .general) {
        let results = entries.compactMap(\.result)
        guard !results.isEmpty else { return }
        do {
            let json = try ExportJSON.encode(results)
            pasteboard.clearContents()
            pasteboard.setString(json, forType: .string)
            exportMessage = L("JSON copied to clipboard.")
        } catch {
            exportMessage = L("Export failed: %@", error.localizedDescription)
        }
    }

    func toggleExpanded(_ id: UUID) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    // MARK: - Notices

    private func showNotice(_ text: String) {
        noticeGeneration += 1
        let generation = noticeGeneration
        notice = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, self.noticeGeneration == generation else { return }
            self.notice = nil
        }
    }

    // MARK: - Production analysis pipeline

    /// validate → run → interpret, all against the Core contract.
    static func analyze(settings: AnalyzerSettings, url: URL) async -> Result<AnalysisResult, AnalyzerFailure> {
        let fm = FileManager.default
        if let message = AnalyzerInvocation.validate(
            binaryPath: settings.binaryPath,
            exists: { fm.fileExists(atPath: $0) },
            isFile: { path in
                var isDirectory: ObjCBool = false
                return fm.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
            }
        ) {
            return .failure(AnalyzerFailure(message))
        }

        let environment = AnalyzerInvocation.environment(
            base: ProcessInfo.processInfo.environment,
            envVars: settings.envVars)

        switch await ProcessRunner.run(
            binary: settings.binaryPath,
            arguments: [url.path],
            environment: environment
        ) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let outcome):
            return AnalyzerInvocation.interpret(
                terminationDescription: outcome.terminationDescription,
                succeeded: outcome.succeeded,
                stdout: outcome.stdout,
                stderr: outcome.stderr)
        }
    }
}
