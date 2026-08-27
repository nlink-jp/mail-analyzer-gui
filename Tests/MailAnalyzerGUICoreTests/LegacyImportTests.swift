import XCTest
@testable import MailAnalyzerGUICore

final class LegacyImportTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "jp.nlink.mail-analyzer-gui.tests.legacy-import"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testParseRealStoreShape() throws {
        let settings = try XCTUnwrap(LegacyImport.parse(try fixtureData("tauri-store")))
        XCTAssertEqual(settings.binaryPath, "/usr/local/bin/mail-analyzer-local")
        XCTAssertEqual(settings.envVars.count, 4)
        XCTAssertEqual(settings.envVars["MAIL_ANALYZER_LOCAL_LANG"], "ja")
        XCTAssertEqual(settings.envVars["MAIL_ANALYZER_LOCAL_API_KEY"], "")
    }

    func testParseMalformedAndKeylessStores() {
        XCTAssertNil(LegacyImport.parse(Data("not json".utf8)))
        XCTAssertNil(LegacyImport.parse(Data("{}".utf8)), "store without a settings key imports nothing")
        // window_state alone is not settings.
        XCTAssertNil(LegacyImport.parse(Data(#"{"window_state":{"x":1}}"#.utf8)))
    }

    func testShouldImportTruthTable() {
        XCTAssertTrue(LegacyImport.shouldImport(flagSet: false, settingsUnset: true))
        XCTAssertFalse(LegacyImport.shouldImport(flagSet: true, settingsUnset: true))
        XCTAssertFalse(LegacyImport.shouldImport(flagSet: false, settingsUnset: false))
        XCTAssertFalse(LegacyImport.shouldImport(flagSet: true, settingsUnset: false))
    }

    func testRunOnceImportsAndSetsFlag() throws {
        let data = try fixtureData("tauri-store")
        let imported = LegacyImport.runOnce(
            defaults: defaults,
            storeURL: URL(fileURLWithPath: "/legacy/settings.json"),
            readFile: { _ in data })
        XCTAssertTrue(imported)
        XCTAssertTrue(defaults.bool(forKey: LegacyImport.flagKey))
        XCTAssertEqual(AnalyzerSettings.load(from: defaults).binaryPath, "/usr/local/bin/mail-analyzer-local")
    }

    func testRunOnceNeverRunsTwice() throws {
        let data = try fixtureData("tauri-store")
        XCTAssertTrue(LegacyImport.runOnce(defaults: defaults, readFile: { _ in data }))
        var reads = 0
        let second = LegacyImport.runOnce(defaults: defaults, readFile: { _ in reads += 1; return data })
        XCTAssertFalse(second)
        XCTAssertEqual(reads, 0, "flagged import must not even read the file")
    }

    func testRunOnceNeverClobbersExistingSettings() throws {
        AnalyzerSettings(binaryPath: "/my/own/analyzer", envVars: [:]).save(to: defaults)
        let data = try fixtureData("tauri-store")
        XCTAssertFalse(LegacyImport.runOnce(defaults: defaults, readFile: { _ in data }))
        XCTAssertEqual(AnalyzerSettings.load(from: defaults).binaryPath, "/my/own/analyzer")
        XCTAssertTrue(defaults.bool(forKey: LegacyImport.flagKey), "flag is set so it never retries")
    }

    func testRunOnceMissingFileStillSetsFlag() {
        XCTAssertFalse(LegacyImport.runOnce(defaults: defaults, readFile: { _ in nil }))
        XCTAssertTrue(defaults.bool(forKey: LegacyImport.flagKey))
        XCTAssertTrue(AnalyzerSettings.isUnset(in: defaults))
    }

    func testDefaultStoreURLShape() {
        let url = LegacyImport.defaultStoreURL(appSupport: URL(fileURLWithPath: "/Users/x/Library/Application Support"))
        XCTAssertEqual(url.path, "/Users/x/Library/Application Support/jp.nlink.mail-analyzer-gui/settings.json")
    }
}
