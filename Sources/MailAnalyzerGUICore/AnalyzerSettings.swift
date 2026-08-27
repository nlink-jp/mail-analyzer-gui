import Foundation

/// Persisted app settings: where the analyzer binary lives and which
/// environment variables to hand it. Values live in UserDefaults (house
/// convention) — note env values, API keys included, are stored in plain
/// text exactly as the legacy Tauri store did; Keychain support is recorded
/// as future work in ADR-0001.
public struct AnalyzerSettings: Equatable {
    public var binaryPath: String
    public var envVars: [String: String]

    public init(binaryPath: String = "", envVars: [String: String] = [:]) {
        self.binaryPath = binaryPath
        self.envVars = envVars
    }

    private enum Key {
        static let binaryPath = "analyzer.binaryPath"
        static let envVars = "analyzer.envVars"
    }

    public static func load(from defaults: UserDefaults = .standard) -> AnalyzerSettings {
        var s = AnalyzerSettings()
        s.binaryPath = defaults.string(forKey: Key.binaryPath) ?? ""
        s.envVars = (defaults.dictionary(forKey: Key.envVars) as? [String: String]) ?? [:]
        return s
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(binaryPath, forKey: Key.binaryPath)
        defaults.set(envVars, forKey: Key.envVars)
    }

    /// True when nothing has been configured yet (used to decide whether the
    /// one-time legacy import may write).
    public static func isUnset(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Key.binaryPath) == nil
            && defaults.object(forKey: Key.envVars) == nil
    }
}
