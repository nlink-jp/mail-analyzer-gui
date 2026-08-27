import XCTest
@testable import MailAnalyzerGUICore

final class AnalyzerSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "jp.nlink.mail-analyzer-gui.tests.settings"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaultsWhenUnset() {
        XCTAssertTrue(AnalyzerSettings.isUnset(in: defaults))
        let s = AnalyzerSettings.load(from: defaults)
        XCTAssertEqual(s, AnalyzerSettings(binaryPath: "", envVars: [:]))
    }

    func testSaveLoadRoundTrip() {
        let s = AnalyzerSettings(
            binaryPath: "/usr/local/bin/mail-analyzer-local",
            envVars: [
                "MAIL_ANALYZER_LOCAL_ENDPOINT": "http://localhost:1234/v1",
                "MAIL_ANALYZER_LOCAL_API_KEY": "",
            ])
        s.save(to: defaults)
        XCTAssertFalse(AnalyzerSettings.isUnset(in: defaults))
        XCTAssertEqual(AnalyzerSettings.load(from: defaults), s)
    }

    func testEmptyValuesSurviveRoundTrip() {
        // Empty env values are stored (meaning "configured but unset"),
        // matching the legacy store semantics.
        let s = AnalyzerSettings(binaryPath: "", envVars: ["KEY": ""])
        s.save(to: defaults)
        XCTAssertEqual(AnalyzerSettings.load(from: defaults).envVars, ["KEY": ""])
        XCTAssertFalse(AnalyzerSettings.isUnset(in: defaults))
    }
}
