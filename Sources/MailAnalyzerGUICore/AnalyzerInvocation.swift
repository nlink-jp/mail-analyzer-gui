import Foundation

/// A human-readable analyzer failure. The message text is the entire payload;
/// it is shown verbatim in the result row's expanded error view.
public struct AnalyzerFailure: Error, Equatable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

// The mail-analyzer subprocess contract: `<binary_path> <file>` with exactly
// one positional argument and no flags. Error strings are part of the
// contract (legacy/src-tauri/src/analyzer.rs) and stay English verbatim.
public enum AnalyzerInvocation {
    /// Pre-flight validation of the configured binary path. Deliberately no
    /// PATH auto-detection and no fallback locations (anti-binary-injection
    /// design from the original RFP). Returns the error message, or nil if ok.
    public static func validate(
        binaryPath: String,
        exists: (String) -> Bool,
        isFile: (String) -> Bool
    ) -> String? {
        if binaryPath.isEmpty {
            return "Analyzer binary path is not configured. Please open Settings and set the path."
        }
        if !exists(binaryPath) {
            return "Analyzer binary not found at: \(binaryPath)\nPlease check the path in Settings."
        }
        if !isFile(binaryPath) {
            return "Path is not a file: \(binaryPath)\nPlease set the path to the analyzer binary."
        }
        return nil
    }

    /// Compose the child environment: the parent environment plus the
    /// configured variables, where an empty value means "leave unset"
    /// (never "override with empty string") — legacy behavior.
    public static func environment(
        base: [String: String],
        envVars: [String: String]
    ) -> [String: String] {
        var env = base
        for (key, value) in envVars where !value.isEmpty {
            env[key] = value
        }
        return env
    }

    /// Map a finished process to a result, reproducing the legacy message
    /// formats. `terminationDescription` is the exit-code/signal text placed
    /// after "Analyzer exited with code ".
    public static func interpret(
        terminationDescription: String,
        succeeded: Bool,
        stdout: String,
        stderr: String
    ) -> Result<AnalysisResult, AnalyzerFailure> {
        if !succeeded {
            var msg = "Analyzer exited with code \(terminationDescription)"
            let trimmedErr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOut = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stderr.isEmpty {
                msg += "\n\nStderr:\n\(trimmedErr)"
            }
            if !stdout.isEmpty && stderr.isEmpty {
                msg += "\n\nOutput:\n\(trimmedOut)"
            }
            return .failure(AnalyzerFailure(msg))
        }

        if stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(AnalyzerFailure("Analyzer returned empty output"))
        }

        do {
            return .success(try AnalysisResultDecoding.decode(Data(stdout.utf8)))
        } catch {
            // prefix(500) cuts on Character boundaries — the legacy Rust byte
            // slice panicked when the 500th byte fell inside a multibyte char.
            return .failure(AnalyzerFailure(
                "Failed to parse analyzer output: \(error.localizedDescription)\n\nRaw output (first 500 chars):\n\(stdout.prefix(500))"
            ))
        }
    }
}
