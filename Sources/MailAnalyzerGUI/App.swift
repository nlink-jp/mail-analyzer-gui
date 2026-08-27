import SwiftUI

// Scaffold entry point — replaced by the real app shell (AppInfo,
// --version intercept, window sizing) in the GUI phase.
@main
struct MailAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("mail-analyzer-gui")
        }
    }
}
