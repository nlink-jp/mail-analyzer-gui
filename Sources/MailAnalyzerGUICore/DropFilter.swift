import Foundation

/// The extension whitelist for dropped files: only .eml and .msg are
/// analyzed (case-insensitive), everything else is rejected — and, unlike
/// the legacy app, rejections surface as a notice instead of vanishing.
public enum DropFilter {
    public static func accepts(filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasSuffix(".eml") || lower.hasSuffix(".msg")
    }

    /// Split paths into accepted and rejected, preserving order.
    public static func partition(paths: [String]) -> (accepted: [String], rejected: [String]) {
        var accepted: [String] = []
        var rejected: [String] = []
        for path in paths {
            if accepts(filename: (path as NSString).lastPathComponent) {
                accepted.append(path)
            } else {
                rejected.append(path)
            }
        }
        return (accepted, rejected)
    }
}
