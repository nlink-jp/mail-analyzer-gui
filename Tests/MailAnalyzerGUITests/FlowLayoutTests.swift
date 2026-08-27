import XCTest
@testable import MailAnalyzerGUI

final class FlowLayoutTests: XCTestCase {
    private func sizes(_ widths: [CGFloat], height: CGFloat = 20) -> [CGSize] {
        widths.map { CGSize(width: $0, height: height) }
    }

    func testSingleLineWhenEverythingFits() {
        let result = FlowLayoutMath.layout(
            sizes: sizes([50, 40, 30]), maxWidth: 200, spacing: 6)
        XCTAssertEqual(result.placements.map(\.y), [0, 0, 0])
        XCTAssertEqual(result.placements.map(\.x), [0, 56, 102])
        // Width is content extent (no trailing spacing), height one line.
        XCTAssertEqual(result.size, CGSize(width: 132, height: 20))
    }

    func testWrapsWhenNextItemWouldOverflow() {
        // 50 + 6 + 40 = 96 fits in 100; the 30 at x=102 would overflow.
        let result = FlowLayoutMath.layout(
            sizes: sizes([50, 40, 30]), maxWidth: 100, spacing: 6)
        XCTAssertEqual(result.placements, [
            FlowLayoutMath.Placement(x: 0, y: 0),
            FlowLayoutMath.Placement(x: 56, y: 0),
            FlowLayoutMath.Placement(x: 0, y: 26),
        ])
        XCTAssertEqual(result.size.height, 46)
    }

    func testItemWiderThanLineGetsItsOwnLine() {
        let result = FlowLayoutMath.layout(
            sizes: sizes([80, 150, 40]), maxWidth: 100, spacing: 6)
        XCTAssertEqual(result.placements.map(\.y), [0, 26, 52])
        // An oversized item is placed at x=0 rather than dropped.
        XCTAssertEqual(result.placements[1].x, 0)
        XCTAssertEqual(result.size.width, 150)
    }

    func testLineHeightFollowsTallestItemPerLine() {
        let result = FlowLayoutMath.layout(
            sizes: [
                CGSize(width: 60, height: 20),
                CGSize(width: 60, height: 30),  // taller, same line
                CGSize(width: 60, height: 20),  // wraps
            ],
            maxWidth: 130, spacing: 6)
        XCTAssertEqual(result.placements.map(\.y), [0, 0, 36])
        XCTAssertEqual(result.size.height, 56)
    }

    func testEmptyInput() {
        let result = FlowLayoutMath.layout(sizes: [], maxWidth: 100, spacing: 6)
        XCTAssertEqual(result.placements, [])
        XCTAssertEqual(result.size, .zero)
    }

    func testUnboundedWidthNeverWraps() {
        let result = FlowLayoutMath.layout(
            sizes: sizes([500, 500, 500]), maxWidth: .infinity, spacing: 6)
        XCTAssertEqual(result.placements.map(\.y), [0, 0, 0])
    }
}
