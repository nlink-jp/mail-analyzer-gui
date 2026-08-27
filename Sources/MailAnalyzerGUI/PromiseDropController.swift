import AppKit
import MailAnalyzerGUICore

/// The impure half of a file-promise drop (Apple Mail et al.): owns the
/// per-drop temp directories, kicks off the promise machinery, polls the
/// directory into the pure PromiseDropSession reducer, and delivers exactly
/// one outcome. Replaces the legacy Rust/ObjC FSEventStream bridge — a
/// 250 ms poll doubles as the reducer's clock, needs no run-loop thread,
/// and tears itself down deterministically.
///
/// Two start modes (measured against real Mail drags, 2026-08):
/// - `start(receivers:)` — modern NSFilePromiseReceiver. Mail offers this
///   only for SINGLE-message drags, with empty fileNames (count is a hint).
/// - `prepareLegacyDestination()` + `startLegacy(expectedCount:)` — the
///   pre-10.12 promise protocol (`com.apple.pasteboard.promised-file-url`),
///   the ONLY thing Mail offers for multi-message drags. The caller gets
///   the exact promised-name count from `namesOfPromisedFilesDropped`, so
///   the reducer completes on size stability without a quiet-window wait.
@MainActor
final class PromiseDropController {
    enum Outcome {
        case files([URL], warning: String?)
        case failure(String)
    }

    /// This drop's own directory (`<tempBase>/<UUID>/`): no snapshot
    /// diffing, no cross-drop races, no filename collisions between two
    /// promised "message.eml".
    let dropDirectory: URL
    private let config: PromiseDropSession.Config
    private let onOutcome: (Outcome) -> Void

    private var session: PromiseDropSession?
    private var completed = false
    private var pollTask: Task<Void, Never>?
    /// Promise readers must run off the main queue (Apple requirement; some
    /// sources deadlock a main-queue reader).
    private let readerQueue = OperationQueue()
    private let startInstant = ContinuousClock.now

    init(
        tempBase: URL,
        config: PromiseDropSession.Config = PromiseDropSession.Config(),
        onOutcome: @escaping (Outcome) -> Void
    ) {
        self.dropDirectory = tempBase.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.config = config
        self.onOutcome = onOutcome
        readerQueue.maxConcurrentOperationCount = 2
    }

    deinit {
        pollTask?.cancel()
    }

    private var elapsed: TimeInterval {
        let components = startInstant.duration(to: .now).components
        return Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }

    // MARK: - Modern path (NSFilePromiseReceiver)

    func start(receivers: [NSFilePromiseReceiver]) {
        let fm = FileManager.default
        do {
            for (index, _) in receivers.enumerated() {
                try fm.createDirectory(
                    at: receiverDirectory(index),
                    withIntermediateDirectories: true)
            }
        } catch {
            finish(with: .failure("Could not create the drop directory: \(error.localizedDescription)"))
            return
        }

        // fileNames is authoritative when populated; Mail leaves it empty,
        // making the count a mere hint (→ quiet-window completion).
        let exact = !receivers.isEmpty && receivers.allSatisfy { !$0.fileNames.isEmpty }
        let expected = receivers.map { max($0.fileNames.count, 1) }.reduce(0, +)
        beginSession(expectedCount: expected, expectedIsExact: exact)

        for (index, receiver) in receivers.enumerated() {
            let directory = receiverDirectory(index)
            let relativePrefix = "r\(index)/"
            // Attempted first — when the reader actually fires the drop
            // completes immediately. With Mail it often never does
            // (platform bug); the poll covers that.
            receiver.receivePromisedFiles(atDestination: directory, options: [:], operationQueue: readerQueue) {
                [weak self] url, error in
                let relative = relativePrefix + url.lastPathComponent
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.feed(.readerFailed(
                            "\(relative): \(error.localizedDescription)", at: self.elapsed))
                    } else {
                        self.feed(.readerDelivered(relative, at: self.elapsed))
                    }
                }
            }
        }
    }

    // MARK: - Legacy path (promised-file-url)

    /// Create and return the destination directory for
    /// `NSDraggingInfo.namesOfPromisedFilesDropped(atDestination:)` — which
    /// must be called inside `performDragOperation`, before `startLegacy`.
    func prepareLegacyDestination() throws -> URL {
        let directory = receiverDirectory(0)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Begin watching for the promised files. `expectedCount` is the exact
    /// promised-name count, so completion needs only size stability.
    func startLegacy(expectedCount: Int) {
        beginSession(expectedCount: expectedCount, expectedIsExact: expectedCount >= 1)
    }

    // MARK: - Shared machinery

    private func beginSession(expectedCount: Int, expectedIsExact: Bool) {
        session = PromiseDropSession(
            expectedCount: expectedCount,
            expectedIsExact: expectedIsExact,
            startedAt: elapsed,
            config: config)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, !self.completed else { return }
                self.feed(.snapshot(self.scan(), at: self.elapsed))
            }
        }
    }

    private func receiverDirectory(_ index: Int) -> URL {
        dropDirectory.appendingPathComponent("r\(index)", isDirectory: true)
    }

    private func feed(_ event: PromiseDropSession.Event) {
        guard !completed, session != nil else { return }
        if case .finished(let outcome) = session!.handle(event) {
            switch outcome {
            case .files(let relativePaths, let warning):
                let urls = relativePaths.map {
                    dropDirectory.appendingPathComponent($0)
                }
                finish(with: .files(urls, warning: warning))
            case .failure(let message):
                finish(with: .failure(message))
            }
        }
    }

    private func finish(with outcome: Outcome) {
        guard !completed else { return }
        completed = true
        pollTask?.cancel()
        pollTask = nil
        onOutcome(outcome)
    }

    /// Relative path → size for every regular file under the drop directory.
    private func scan() -> [String: UInt64] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: dropDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }

        var listing: [String: UInt64] = [:]
        let basePath = dropDirectory.standardizedFileURL.path
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(basePath + "/") else { continue }
            let relative = String(path.dropFirst(basePath.count + 1))
            listing[relative] = UInt64(values.fileSize ?? 0)
        }
        return listing
    }
}
