import Foundation

/// One KEY/VALUE row in the settings editor. Rows are ordered (unlike the
/// persisted [String: String]), so the editor can display template order.
public struct EnvRow: Equatable, Identifiable {
    public var id: UUID
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.id = UUID()
        self.key = key
        self.value = value
    }
}

/// The two backend templates hard-coded in the legacy settings screen
/// (legacy/src/lib/components/Settings.svelte) — names, keys, placeholders
/// verbatim. Placeholders are hints, never default values.
public struct EnvTemplate: Equatable {
    public let name: String
    public let vars: [(key: String, placeholder: String)]

    public static let vertexAI = EnvTemplate(
        name: "mail-analyzer (Vertex AI)",
        vars: [
            ("MAIL_ANALYZER_PROJECT", "GCP Project ID"),
            ("MAIL_ANALYZER_LOCATION", "us-central1"),
            ("MAIL_ANALYZER_MODEL", "gemini-2.5-flash"),
            ("MAIL_ANALYZER_LANG", "(optional)"),
        ])

    public static let localLLM = EnvTemplate(
        name: "mail-analyzer-local (Local LLM)",
        vars: [
            ("MAIL_ANALYZER_LOCAL_ENDPOINT", "http://localhost:1234/v1"),
            ("MAIL_ANALYZER_LOCAL_MODEL", "google/gemma-4-26b-a4b"),
            ("MAIL_ANALYZER_LOCAL_API_KEY", "(optional)"),
            ("MAIL_ANALYZER_LOCAL_LANG", "(optional)"),
        ])

    public static let all: [EnvTemplate] = [.vertexAI, .localLLM]

    /// Replace the row set with this template's keys (template order),
    /// carrying over values only for matching keys. Keys outside the
    /// template are dropped — legacy behavior.
    public func apply(to current: [EnvRow]) -> [EnvRow] {
        let existing = Dictionary(current.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
        return vars.map { EnvRow(key: $0.key, value: existing[$0.key] ?? "") }
    }

    /// Placeholder for a key, looked up across all templates (hand-typed
    /// keys get a placeholder too when they match) — legacy placeholderFor.
    public static func placeholder(for key: String) -> String {
        for template in all {
            if let match = template.vars.first(where: { $0.key == key }) {
                return match.placeholder
            }
        }
        return ""
    }

    public static func == (lhs: EnvTemplate, rhs: EnvTemplate) -> Bool {
        lhs.name == rhs.name && lhs.vars.elementsEqual(rhs.vars, by: ==)
    }
}

public enum EnvRows {
    /// Editor rows from persisted settings: sorted by key for a stable
    /// display order (the legacy HashMap order was unstable), with one empty
    /// row when there is nothing to show — legacy behavior.
    public static func fromSettings(_ envVars: [String: String]) -> [EnvRow] {
        let rows = envVars.sorted { $0.key < $1.key }.map { EnvRow(key: $0.key, value: $0.value) }
        return rows.isEmpty ? [EnvRow(key: "", value: "")] : rows
    }

    /// Persisted map from editor rows: keys are trimmed, empty keys are
    /// skipped, empty values are kept — legacy save semantics.
    public static func sanitizeForSave(_ rows: [EnvRow]) -> [String: String] {
        var result: [String: String] = [:]
        for row in rows {
            let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                result[key] = row.value
            }
        }
        return result
    }
}
