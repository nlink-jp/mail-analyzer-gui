import XCTest
@testable import MailAnalyzerGUI

final class AppInfoTests: XCTestCase {
    func testNormalizeStripsLeadingV() {
        XCTAssertEqual(AppInfo.normalize("v0.3.0"), "0.3.0")
        XCTAssertEqual(AppInfo.normalize("0.3.0"), "0.3.0")
        XCTAssertEqual(AppInfo.normalize("v0.3.0-2-gabc123-dirty"), "0.3.0-2-gabc123-dirty")
    }
}
