import Foundation

// Pure state machine for one file-promise drop (Apple Mail et al.).
//
// Background: NSFilePromiseReceiver's reader block is unreliable with Apple
// Mail (known platform bug — the legacy app worked around it with an
// FSEventStream). This reducer makes the workaround honest: the controller
// polls the per-drop temp directory and feeds snapshots in; completion is
// decided from file-size quiescence, an expected-count *hint*, and a hard
// deadline that ALWAYS produces an outcome. The legacy implementation went
// permanently silent when the promised files never appeared.
//
// All timestamps are caller-supplied seconds (injected clock): no Date(),
// no timers, fully unit-testable.
public struct PromiseDropSession {
    public struct Config: Equatable {
        /// A file whose size has not changed for this long is considered
        /// fully written (guards the create-then-write race the legacy
        /// FSEvents handler had).
        public var stableWindow: TimeInterval
        /// No new files and no growth for this long → the drop is over,
        /// even if fewer files than expected arrived (Mail's receiver
        /// count is not a reliable file count).
        public var quietWindow: TimeInterval
        /// Hard cap: always yields an outcome, never silence.
        public var deadline: TimeInterval

        public init(
            stableWindow: TimeInterval = 0.5,
            quietWindow: TimeInterval = 2.0,
            deadline: TimeInterval = 15.0
        ) {
            self.stableWindow = stableWindow
            self.quietWindow = quietWindow
            self.deadline = deadline
        }
    }

    public enum Event {
        /// Full scan of the drop's own temp directory: relative path → size.
        case snapshot([String: UInt64], at: TimeInterval)
        /// The promise receiver's reader block actually completed one file.
        case readerDelivered(String, at: TimeInterval)
        /// The reader block reported an error.
        case readerFailed(String, at: TimeInterval)
    }

    public enum Outcome: Equatable {
        /// Relative paths of the received files (sorted), plus a warning
        /// when the count fell short of the hint or the deadline hit.
        case files([String], warning: String?)
        case failure(String)
    }

    public enum Step: Equatable {
        case continuePolling
        case finished(Outcome)
    }

    private let expected: Int
    private let startedAt: TimeInterval
    private let config: Config

    private struct FileState {
        var size: UInt64
        var lastChanged: TimeInterval
    }

    private var files: [String: FileState] = [:]
    private var readerDelivered: Set<String> = []
    private var readerErrors: [String] = []
    private var lastActivity: TimeInterval
    private var finished = false

    public init(expectedCount: Int, startedAt: TimeInterval, config: Config = Config()) {
        self.expected = max(expectedCount, 1)
        self.startedAt = startedAt
        self.config = config
        self.lastActivity = startedAt
    }

    public mutating func handle(_ event: Event) -> Step {
        if finished { return .continuePolling }

        let now: TimeInterval
        switch event {
        case .snapshot(let listing, let at):
            now = at
            ingest(listing, at: at)
        case .readerDelivered(let path, let at):
            now = at
            if !isDotFile(path) {
                readerDelivered.insert(path)
                if files[path] == nil {
                    files[path] = FileState(size: 0, lastChanged: at)
                }
                lastActivity = at
            }
        case .readerFailed(let message, let at):
            now = at
            readerErrors.append(message)
        }

        if let outcome = evaluate(now: now) {
            finished = true
            return .finished(outcome)
        }
        return .continuePolling
    }

    private mutating func ingest(_ listing: [String: UInt64], at: TimeInterval) {
        for (path, size) in listing where !isDotFile(path) {
            if let existing = files[path] {
                if existing.size != size {
                    files[path] = FileState(size: size, lastChanged: at)
                    lastActivity = at
                }
            } else {
                files[path] = FileState(size: size, lastChanged: at)
                lastActivity = at
            }
        }
    }

    private func evaluate(now: TimeInterval) -> Outcome? {
        // 1. The happy path: the reader block worked for every promise.
        if readerDelivered.count >= expected {
            return .files(sortedPaths(), warning: nil)
        }

        let allStable = !files.isEmpty && files.values.allSatisfy {
            now - $0.lastChanged >= config.stableWindow
        }

        // 2. All files on disk are fully written and the drop has gone
        //    quiet. The quiet window is required even when the count hint is
        //    already met: the hint under-counts for Mail multi-message drags
        //    (one receiver, empty fileNames → hint 1), and completing on
        //    "count reached + stable" would race files the source has not
        //    started writing yet. Deliver whatever arrived; warn on shortfall
        //    (the hint over-counts for other drags).
        if allStable && now - lastActivity >= config.quietWindow {
            return .files(sortedPaths(), warning: shortfallWarning())
        }

        // 3. Hard deadline — never silent.
        if now - startedAt >= config.deadline {
            if files.isEmpty {
                var msg = "No files were received from the drag source within \(Int(config.deadline))s."
                if !readerErrors.isEmpty {
                    msg += "\n" + readerErrors.joined(separator: "\n")
                }
                msg += "\nTry saving the message as .eml in Finder and dropping it from there."
                return .failure(msg)
            }
            return .files(sortedPaths(), warning: shortfallWarning()
                ?? "Timed out waiting for promised files; proceeding with \(files.count) file(s).")
        }

        return nil
    }

    private func shortfallWarning() -> String? {
        files.count < expected ? "Received \(files.count) of \(expected) promised files." : nil
    }

    private func sortedPaths() -> [String] {
        files.keys.sorted()
    }

    private func isDotFile(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return name.hasPrefix(".")
    }
}
