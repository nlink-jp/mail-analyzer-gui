import XCTest
@testable import MailAnalyzerGUI

final class LocalizationTests: XCTestCase {
    private func stringsTable(localization: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            L10nResources.bundle.url(
                forResource: "Localizable", withExtension: "strings",
                subdirectory: nil, localization: localization),
            "missing \(localization).lproj/Localizable.strings")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return dict
    }

    // Every key must exist in both languages — a key added to one table only
    // silently falls back to English at runtime.
    func testEnJaKeyParity() throws {
        let en = try stringsTable(localization: "en")
        let ja = try stringsTable(localization: "ja")
        XCTAssertFalse(en.isEmpty)
        let missingInJa = Set(en.keys).subtracting(ja.keys).sorted()
        let missingInEn = Set(ja.keys).subtracting(en.keys).sorted()
        XCTAssertEqual(missingInJa, [], "keys missing from ja.lproj")
        XCTAssertEqual(missingInEn, [], "keys missing from en.lproj")
    }

    // en is an identity table: key == value, so an untranslated locale
    // renders the source text.
    func testEnglishIsIdentityTable() throws {
        let en = try stringsTable(localization: "en")
        for (key, value) in en {
            XCTAssertEqual(key, value, "en.lproj must map keys to themselves")
        }
    }

    // Format placeholders must survive translation (%d / %@ / %llu count and
    // kind must match, or String(format:) corrupts at runtime).
    func testFormatPlaceholdersMatch() throws {
        let en = try stringsTable(localization: "en")
        let ja = try stringsTable(localization: "ja")
        let pattern = try NSRegularExpression(pattern: "%(llu|d|@)")
        func placeholders(_ s: String) -> [String] {
            pattern.matches(in: s, range: NSRange(s.startIndex..., in: s))
                .compactMap { Range($0.range, in: s).map { String(s[$0]) } }
                .sorted()
        }
        for (key, enValue) in en {
            guard let jaValue = ja[key] else { continue }
            XCTAssertEqual(
                placeholders(enValue), placeholders(jaValue),
                "placeholder mismatch for key: \(key)")
        }
    }

    func testLookupFallsBackToKey() {
        XCTAssertEqual(L("definitely-not-a-key"), "definitely-not-a-key")
    }
}
