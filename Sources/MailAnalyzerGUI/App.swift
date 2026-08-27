import SwiftUI
import MailAnalyzerGUICore

enum AppInfo {
    /// The app's short version (from Info.plist), with any leading "v"
    /// stripped. Falls back to "dev" only when there is genuinely no bundle
    /// (e.g. `swift run`).
    static var version: String {
        if let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !value.isEmpty {
            return normalize(value)
        }
        // Launched through the Homebrew cask's symlink in bin/, Bundle.main
        // is not the .app — read Info.plist relative to the real executable
        // (…/Contents/MacOS/MailAnalyzerGUI → …/Contents/Info.plist).
        if let plist = infoPlistBesideExecutable(),
           let value = plist["CFBundleShortVersionString"] as? String {
            return normalize(value)
        }
        return "dev"
    }

    private static func infoPlistBesideExecutable() -> NSDictionary? {
        let candidates = [
            Bundle.main.executableURL,
            URL(fileURLWithPath: CommandLine.arguments.first ?? ""),
        ].compactMap { $0?.resolvingSymlinksInPath() }
        for executable in candidates {
            let plist = executable
                .deletingLastPathComponent()   // MacOS/
                .deletingLastPathComponent()   // Contents/
                .appendingPathComponent("Info.plist")
            if let dict = NSDictionary(contentsOf: plist) { return dict }
        }
        return nil
    }

    static func normalize(_ raw: String) -> String {
        raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
    }
}

@main
enum Main {
    static func main() {
        // `brew test` and release verification call `mail-analyzer-gui
        // --version`; answer on stdout and exit before any AppKit/SwiftUI
        // machinery starts.
        let args = CommandLine.arguments.dropFirst()
        if args.contains("--version") || args.contains("-v") {
            print("mail-analyzer-gui \(AppInfo.version)")
            exit(0)
        }
        MailAnalyzerApp.main()
    }
}

struct MailAnalyzerApp: App {
    var body: some Scene {
        WindowGroup("mail-analyzer-gui") {
            ContentView()
        }
        .defaultSize(width: 720, height: 640)
    }
}

// Placeholder until the real content view lands.
struct ContentView: View {
    var body: some View {
        Text("mail-analyzer-gui")
            .frame(minWidth: 480, minHeight: 360)
    }
}
