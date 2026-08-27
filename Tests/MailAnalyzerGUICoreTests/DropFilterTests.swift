import XCTest
@testable import MailAnalyzerGUICore

final class DropFilterTests: XCTestCase {
    func testAcceptsEmlAndMsgCaseInsensitive() {
        XCTAssertTrue(DropFilter.accepts(filename: "mail.eml"))
        XCTAssertTrue(DropFilter.accepts(filename: "MAIL.EML"))
        XCTAssertTrue(DropFilter.accepts(filename: "report.Msg"))
        XCTAssertTrue(DropFilter.accepts(filename: "weird.name.v2.eml"))
    }

    func testRejectsOtherExtensions() {
        XCTAssertFalse(DropFilter.accepts(filename: "notes.txt"))
        XCTAssertFalse(DropFilter.accepts(filename: "eml"))
        XCTAssertFalse(DropFilter.accepts(filename: "archive.eml.zip"))
        XCTAssertFalse(DropFilter.accepts(filename: "noextension"))
        XCTAssertFalse(DropFilter.accepts(filename: ""))
    }

    func testPartitionPreservesOrder() {
        let (accepted, rejected) = DropFilter.partition(paths: [
            "/drop/a.eml", "/drop/b.txt", "/drop/c.msg", "/drop/d.png",
        ])
        XCTAssertEqual(accepted, ["/drop/a.eml", "/drop/c.msg"])
        XCTAssertEqual(rejected, ["/drop/b.txt", "/drop/d.png"])
    }
}
