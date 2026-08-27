import XCTest
@testable import MailAnalyzerGUI

final class ResourceBundleTests: XCTestCase {
    func testSearchDirectoriesOrderAndNilCompaction() {
        let a = URL(fileURLWithPath: "/App.app/Contents/Resources")
        let c = URL(fileURLWithPath: "/build/debug")
        let dirs = ResourceBundleLocator.searchDirectories(
            mainResourceURL: a, mainBundleURL: nil, codeDirectoryURL: c)
        XCTAssertEqual(dirs, [a, c])
    }

    func testLocateReturnsFirstExistingCandidate() {
        let dirs = [
            URL(fileURLWithPath: "/first"),
            URL(fileURLWithPath: "/second"),
        ]
        let found = ResourceBundleLocator.locate(bundleName: "X_X", in: dirs) { url in
            url.path == "/second/X_X.bundle"
        }
        XCTAssertEqual(found?.path, "/second/X_X.bundle")
        XCTAssertNil(ResourceBundleLocator.locate(bundleName: "X_X", in: dirs) { _ in false })
    }

    // In the test process the bundle must resolve (SwiftPM stages it beside
    // the code bundle) — this is the regression guard for the Bundle.module
    // trap.
    func testResolveFindsRealBundleInTests() {
        XCTAssertNotNil(
            L10nResources.bundle.url(
                forResource: "Localizable", withExtension: "strings",
                subdirectory: nil, localization: "ja"))
    }
}
