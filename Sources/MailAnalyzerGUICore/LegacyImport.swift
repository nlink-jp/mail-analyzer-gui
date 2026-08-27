import Foundation

// One-time import of the legacy Tauri store
// (~/Library/Application Support/jp.nlink.mail-analyzer-gui/settings.json)
// into UserDefaults. The old file is never written or deleted — the Tauri
// app may coexist during the transition; the Homebrew cask zap covers
// eventual cleanup. window_state is deliberately ignored (window frames use
// the standard restoration machinery now).
public enum LegacyImport {
    public static let flagKey = "migration.importedTauriSettings"

    private struct TauriStore: Decodable {
        struct StoredSettings: Decodable {
            var binary_path: String?
            var env_vars: [String: String]?
        }
        var settings: StoredSettings?
    }

    /// Parse the Tauri store file. Returns nil for malformed JSON or a store
    /// without a "settings" key.
    public static func parse(_ data: Data) -> AnalyzerSettings? {
        guard let store = try? JSONDecoder().decode(TauriStore.self, from: data),
              let stored = store.settings else {
            return nil
        }
        return AnalyzerSettings(
            binaryPath: stored.binary_path ?? "",
            envVars: stored.env_vars ?? [:])
    }

    /// The import may write only on a truly first launch: never twice
    /// (flagSet), and never over settings the user already created.
    public static func shouldImport(flagSet: Bool, settingsUnset: Bool) -> Bool {
        !flagSet && settingsUnset
    }

    /// Default legacy store location (the bundle ID is unchanged, so this is
    /// the same directory the Tauri build wrote to).
    public static func defaultStoreURL(
        appSupport: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    ) -> URL {
        appSupport
            .appendingPathComponent("jp.nlink.mail-analyzer-gui", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// Run the one-time import. Always sets the flag afterwards — including
    /// when the file is missing or malformed (never retried, never surfaced
    /// to the user; failures go to stderr only). Returns true if settings
    /// were imported.
    @discardableResult
    public static func runOnce(
        defaults: UserDefaults = .standard,
        storeURL: URL? = nil,
        readFile: (URL) -> Data? = { try? Data(contentsOf: $0) }
    ) -> Bool {
        let flagSet = defaults.bool(forKey: flagKey)
        guard shouldImport(flagSet: flagSet, settingsUnset: AnalyzerSettings.isUnset(in: defaults)) else {
            if !flagSet { defaults.set(true, forKey: flagKey) }
            return false
        }
        defaults.set(true, forKey: flagKey)

        let url = storeURL ?? defaultStoreURL()
        guard let data = readFile(url) else {
            return false
        }
        guard let settings = parse(data) else {
            FileHandle.standardError.write(Data("[legacy-import] unreadable Tauri store at \(url.path)\n".utf8))
            return false
        }
        settings.save(to: defaults)
        return true
    }
}
