import XCTest
@testable import MailAnalyzerGUICore

func fixtureData(_ name: String) throws -> Data {
    let url = try XCTUnwrap(
        Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "testdata"),
        "missing fixture testdata/\(name).json"
    )
    return try Data(contentsOf: url)
}

final class AnalysisResultTests: XCTestCase {
    func testDecodeFullFixture() throws {
        let result = try AnalysisResultDecoding.decode(try fixtureData("full"))
        XCTAssertEqual(result.sourceFile, "/tmp/sample.eml")
        XCTAssertEqual(result.messageID, "<20260501.1234@mail.example.com>")
        XCTAssertEqual(result.subject, "緊急: アカウント確認のお願い")
        XCTAssertEqual(result.to.count, 2)
        XCTAssertEqual(result.indicators.authentication.spf, "softfail")
        XCTAssertTrue(result.indicators.sender.fromReturnPathMismatch)
        XCTAssertEqual(result.indicators.urls.count, 2)
        XCTAssertTrue(result.indicators.urls[0].suspicious)
        XCTAssertEqual(result.indicators.attachments.count, 1)
        XCTAssertEqual(result.indicators.attachments[0].size, 482_304)
        XCTAssertEqual(result.indicators.routing.hopCount, 6)
        XCTAssertEqual(result.indicators.routing.suspiciousHops.count, 1)
        XCTAssertTrue(result.judgment.isSuspicious)
        XCTAssertEqual(result.judgment.category, "phishing")
        XCTAssertEqual(result.judgment.confidence, 0.94, accuracy: 1e-9)
        XCTAssertEqual(result.judgment.reasons.count, 2)
        XCTAssertEqual(result.judgment.tags, ["credential-harvesting", "homoglyph", "banking"])
    }

    // The Go analyzer emits nil slices as explicit JSON null in exactly six
    // array fields; all must decode as empty arrays (legacy deserialize_null_vec).
    func testDecodeNullArraysAsEmpty() throws {
        let result = try AnalysisResultDecoding.decode(try fixtureData("null-arrays"))
        XCTAssertEqual(result.to, [])
        XCTAssertEqual(result.indicators.urls, [])
        XCTAssertEqual(result.indicators.attachments, [])
        XCTAssertEqual(result.indicators.routing.suspiciousHops, [])
        XCTAssertEqual(result.judgment.reasons, [])
        XCTAssertEqual(result.judgment.tags, [])
        XCTAssertEqual(result.judgment.category, "safe")
    }

    func testDecodeMinimalRequiredOnly() throws {
        let result = try AnalysisResultDecoding.decode(try fixtureData("minimal"))
        XCTAssertEqual(result.sourceFile, "/tmp/minimal.eml")
        XCTAssertEqual(result.subject, "")
        XCTAssertEqual(result.to, [])
        XCTAssertEqual(result.indicators.authentication.spf, "")
        XCTAssertFalse(result.indicators.sender.displayNameSpoofing)
        XCTAssertEqual(result.indicators.routing.hopCount, 0)
        XCTAssertFalse(result.judgment.isSuspicious)
        XCTAssertEqual(result.judgment.confidence, 0.0)
    }

    func testDecodeMissingOptionalFieldsUseDefaults() throws {
        let result = try AnalysisResultDecoding.decode(try fixtureData("missing-fields"))
        XCTAssertEqual(result.subject, "Partial output")
        XCTAssertEqual(result.from, "")
        XCTAssertEqual(result.indicators.urls.count, 1)
        XCTAssertEqual(result.indicators.urls[0].url, "https://example.com")
        XCTAssertFalse(result.indicators.urls[0].suspicious)
        XCTAssertEqual(result.indicators.attachments, [])
        XCTAssertEqual(result.judgment.category, "spam")
    }

    // Required keys must stay required: `{}` and judgment-less output must be
    // a parse error (legacy behavior), never a defaulted "safe" result.
    func testDecodeRejectsMissingRequiredKeys() {
        XCTAssertThrowsError(try AnalysisResultDecoding.decode(Data("{}".utf8)))
        let noJudgment = """
        {"source_file":"a","hash":"b","indicators":{"authentication":{},"sender":{},"routing":{}}}
        """
        XCTAssertThrowsError(try AnalysisResultDecoding.decode(Data(noJudgment.utf8)))
        let noIsSuspicious = """
        {"source_file":"a","hash":"b","indicators":{"authentication":{},"sender":{},"routing":{}},"judgment":{}}
        """
        XCTAssertThrowsError(try AnalysisResultDecoding.decode(Data(noIsSuspicious.utf8)))
    }

    func testRoundTripThroughExportEncoding() throws {
        let original = try AnalysisResultDecoding.decode(try fixtureData("full"))
        let exported = try ExportJSON.encode([original])
        let reDecoded = try JSONDecoder().decode([AnalysisResult].self, from: Data(exported.utf8))
        XCTAssertEqual(reDecoded, [original])
    }

    func testExportKeepsListOrderAndAllKeys() throws {
        let a = try AnalysisResultDecoding.decode(try fixtureData("full"))
        let b = try AnalysisResultDecoding.decode(try fixtureData("minimal"))
        let exported = try ExportJSON.encode([a, b])
        let reDecoded = try JSONDecoder().decode([AnalysisResult].self, from: Data(exported.utf8))
        XCTAssertEqual(reDecoded.map(\.sourceFile), ["/tmp/sample.eml", "/tmp/minimal.eml"])
        // Fields hidden in the UI still export (legacy parity).
        XCTAssertTrue(exported.contains("\"message_id\""))
        XCTAssertTrue(exported.contains("\"source_file\""))
        XCTAssertTrue(exported.contains("\"to\""))
        XCTAssertTrue(exported.contains("\"hash\""))
        // Pretty-printed, slashes unescaped (legacy serde_json::to_string_pretty).
        XCTAssertTrue(exported.contains("\n"))
        XCTAssertTrue(exported.contains("https://examp1e-bank.com/login"))
    }
}
