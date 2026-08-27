import XCTest
@testable import MailAnalyzerGUICore

final class EnvTemplatesTests: XCTestCase {
    func testTemplateContentsMatchLegacy() {
        XCTAssertEqual(EnvTemplate.vertexAI.name, "mail-analyzer (Vertex AI)")
        XCTAssertEqual(EnvTemplate.vertexAI.vars.map(\.key), [
            "MAIL_ANALYZER_PROJECT", "MAIL_ANALYZER_LOCATION",
            "MAIL_ANALYZER_MODEL", "MAIL_ANALYZER_LANG",
        ])
        XCTAssertEqual(EnvTemplate.localLLM.name, "mail-analyzer-local (Local LLM)")
        XCTAssertEqual(EnvTemplate.localLLM.vars.map(\.key), [
            "MAIL_ANALYZER_LOCAL_ENDPOINT", "MAIL_ANALYZER_LOCAL_MODEL",
            "MAIL_ANALYZER_LOCAL_API_KEY", "MAIL_ANALYZER_LOCAL_LANG",
        ])
    }

    func testApplyReplacesRowsAndCarriesMatchingValues() {
        let current = [
            EnvRow(key: "MAIL_ANALYZER_PROJECT", value: "my-project"),
            EnvRow(key: "UNRELATED_KEY", value: "kept-nowhere"),
        ]
        let rows = EnvTemplate.vertexAI.apply(to: current)
        XCTAssertEqual(rows.map(\.key), EnvTemplate.vertexAI.vars.map(\.key))
        XCTAssertEqual(rows[0].value, "my-project")
        XCTAssertEqual(rows[1].value, "")
        // Keys outside the template are dropped (legacy behavior).
        XCTAssertFalse(rows.contains { $0.key == "UNRELATED_KEY" })
    }

    func testApplySwitchingTemplatesDropsOtherBackendKeys() {
        let vertexRows = EnvTemplate.vertexAI.apply(to: [])
        let localRows = EnvTemplate.localLLM.apply(to: vertexRows)
        XCTAssertEqual(localRows.map(\.key), EnvTemplate.localLLM.vars.map(\.key))
        XCTAssertTrue(localRows.allSatisfy { $0.value.isEmpty })
    }

    func testPlaceholderLookupAcrossTemplates() {
        XCTAssertEqual(EnvTemplate.placeholder(for: "MAIL_ANALYZER_LOCATION"), "global")
        XCTAssertEqual(EnvTemplate.placeholder(for: "MAIL_ANALYZER_LOCAL_ENDPOINT"), "http://localhost:1234/v1")
        XCTAssertEqual(EnvTemplate.placeholder(for: "SOMETHING_ELSE"), "")
    }

    func testFromSettingsSortsKeysAndInsertsEmptyRow() {
        XCTAssertEqual(EnvRows.fromSettings([:]).map(\.key), [""])
        let rows = EnvRows.fromSettings(["B_KEY": "2", "A_KEY": "1"])
        XCTAssertEqual(rows.map(\.key), ["A_KEY", "B_KEY"])
    }

    func testSanitizeForSaveTrimsAndSkips() {
        let rows = [
            EnvRow(key: "  MAIL_ANALYZER_PROJECT  ", value: "proj"),
            EnvRow(key: "   ", value: "dropped"),
            EnvRow(key: "", value: "dropped"),
            EnvRow(key: "EMPTY_VALUE", value: ""),
        ]
        let saved = EnvRows.sanitizeForSave(rows)
        XCTAssertEqual(saved, [
            "MAIL_ANALYZER_PROJECT": "proj",
            "EMPTY_VALUE": "",
        ])
    }
}
