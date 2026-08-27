import AppKit
import MailAnalyzerGUICore

/// The impure half of a file-promise drop (Apple Mail et al.): owns the
/// per-drop temp directories, kicks off the promise receivers, polls the
/// directory into the pure PromiseDropSession reducer, and delivers exactly
/// one outcome. Replaces the legacy Rust/ObjC FSEventStream bridge — a
/// 250 ms poll doubles as the reducer's clock, needs no run-loop thread,
/// and tears itself down deterministically.
@MainActor
final class PromiseDropController {
    enum Outcome {
        case files([URL], warning: String?)
        case failure(String)
    }

    private let receivers: [NSFilePromiseReceiver]
    /// This drop's own directory (`<tempBase>/<UUID>/` with `r<i>/` per
    /// receiver): no snapshot diffing, no cross-drop races, no filename
    /// collisions between two promised "message.eml".
    let dropDirectory: URL
    private let onOutcome: (Outcome) -> Void

    private var session: PromiseDropSession
    private var completed = false
    private var pollTask: Task<Void, Never>?
    /// Promise readers must run off the main queue (Apple requirement; some
    /// sources deadlock a main-queue reader).
    private let readerQueue = OperationQueue()
    private let startInstant = ContinuousClock.now

    init(
        receivers: [NSFilePromiseReceiver],
        tempBase: URL,
        config: PromiseDropSession.Config = PromiseDropSession.Config(),
        onOutcome: @escaping (Outcome) -> Void
    ) {
        self.receivers = receivers
        self.dropDirectory = tempBase.appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.onOutcome = onOutcome
        // Receiver count is a HINT: Mail often reports one receiver with
        // empty fileNames for a multi-message drag.
        let expected = receivers.map { max($0.fileNames.count, 1) }.reduce(0, +)
        self.session = PromiseDropSession(expectedCount: expected, startedAt: 0, config: config)
        readerQueue.maxConcurrentOperationCount = 2
    }

    deinit {
        pollTask?.cancel()
    }

    private var elapsed: TimeInterval {
        let components = startInstant.duration(to: .now).components
        return Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }

    func start() {
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

        for (index, receiver) in receivers.enumerated() {
            let directory = receiverDirectory(index)
            let relativePrefix = "r\(index)/"
            // Attempted first — when the reader actually fires (non-Mail
            // promise sources) the drop completes without waiting for
            // quiescence. With Mail it often never does (platform bug); the
            // poll below covers that.
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
        guard !completed else { return }
        if case .finished(let outcome) = session.handle(event) {
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
