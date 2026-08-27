import Foundation

/// Raw outcome of a finished child process, ready for
/// `AnalyzerInvocation.interpret`.
public struct ProcessOutcome: Equatable {
    public let terminationDescription: String
    public let succeeded: Bool
    public let stdout: String
    public let stderr: String
}

// The only impure Core component: runs the analyzer binary. stdin is null,
// both pipes are drained concurrently before waiting on exit (a full pipe
// buffer would otherwise deadlock the child), and a hard timeout terminates
// a hung analyzer — the legacy app had no timeout and hung forever when the
// backing LLM did.
public enum ProcessRunner {
    public static let analysisTimeout: TimeInterval = 300
    static let killGrace: TimeInterval = 5

    public static func run(
        binary: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval = analysisTimeout
    ) async -> Result<ProcessOutcome, AnalyzerFailure> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return .failure(AnalyzerFailure(
                "Failed to execute analyzer: \(error.localizedDescription)\nBinary: \(binary)"))
        }

        async let stdoutData = readToEnd(outPipe.fileHandleForReading)
        async let stderrData = readToEnd(errPipe.fileHandleForReading)

        var timedOut = false
        if await waitForExit(process, upTo: timeout) == false {
            timedOut = true
            process.terminate()
            if await waitForExit(process, upTo: killGrace) == false {
                kill(process.processIdentifier, SIGKILL)
                _ = await waitForExit(process, upTo: killGrace)
            }
        }

        let stdout = String(decoding: await stdoutData, as: UTF8.self)
        let stderr = String(decoding: await stderrData, as: UTF8.self)

        if timedOut {
            return .failure(AnalyzerFailure(
                "Analysis timed out after \(Int(timeout))s. The analyzer process was terminated."))
        }

        let status = process.terminationStatus
        let description: String
        if process.terminationReason == .uncaughtSignal {
            description = "signal \(status)"
        } else {
            description = "\(status)"
        }
        return .success(ProcessOutcome(
            terminationDescription: description,
            succeeded: process.terminationReason == .exit && status == 0,
            stdout: stdout,
            stderr: stderr))
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }

    /// Poll for process exit up to `upTo` seconds (50 ms cadence — worst case
    /// a handful of stats over the whole timeout; no termination-handler /
    /// stream races). Returns true if the process exited within the window.
    private static func waitForExit(_ process: Process, upTo seconds: TimeInterval) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while process.isRunning {
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return true
    }
}
