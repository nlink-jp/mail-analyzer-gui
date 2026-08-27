// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MailAnalyzerGUI",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        // UI-independent logic: analyzer result schema, subprocess contract,
        // settings, promise-drop state machine. No AppKit imports allowed.
        .target(
            name: "MailAnalyzerGUICore",
            path: "Sources/MailAnalyzerGUICore"
        ),
        .executableTarget(
            name: "MailAnalyzerGUI",
            dependencies: ["MailAnalyzerGUICore"],
            path: "Sources/MailAnalyzerGUI"
        ),
        .testTarget(
            name: "MailAnalyzerGUICoreTests",
            dependencies: ["MailAnalyzerGUICore"],
            path: "Tests/MailAnalyzerGUICoreTests"
        ),
        .testTarget(
            name: "MailAnalyzerGUITests",
            dependencies: ["MailAnalyzerGUI"],
            path: "Tests/MailAnalyzerGUITests"
        ),
    ]
)
