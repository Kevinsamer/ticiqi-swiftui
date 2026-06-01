//  Unit tests for CoreTextMetrics — totalHeight calculation
//  ticiqiTests

import XCTest
@testable import ticiqi

final class CoreTextMetricsTests: XCTestCase {

    // MARK: - totalHeight

    func testTotalHeightReturnsPositiveForValidContent() {
        let height = CoreTextMetrics.totalHeight(
            content: "Hello World\nSecond Line",
            fontSize: 48,
            width: 768
        )
        XCTAssertGreaterThan(height, 0)
    }

    func testTotalHeightReturnsZeroForEmptyContent() {
        let height = CoreTextMetrics.totalHeight(content: "", fontSize: 48, width: 768)
        XCTAssertEqual(height, 0)
    }

    func testTotalHeightReturnsZeroForZeroWidth() {
        let height = CoreTextMetrics.totalHeight(content: "Hello", fontSize: 48, width: 0)
        XCTAssertEqual(height, 0)
    }

    func testTotalHeightIncreasesWithMoreContent() {
        let short = CoreTextMetrics.totalHeight(content: "Hello", fontSize: 48, width: 768)
        let long = CoreTextMetrics.totalHeight(content: String(repeating: "Hello\n", count: 20), fontSize: 48, width: 768)
        XCTAssertGreaterThan(long, short)
    }

    func testTotalHeightIncreasesWithLargerFontSize() {
        let small = CoreTextMetrics.totalHeight(content: "Hello World", fontSize: 20, width: 768)
        let large = CoreTextMetrics.totalHeight(content: "Hello World", fontSize: 80, width: 768)
        XCTAssertGreaterThan(large, small)
    }

    func testTotalHeightIncreasesWithNarrowerWidth() {
        let wide = CoreTextMetrics.totalHeight(content: "This is a long text that should wrap", fontSize: 48, width: 1024)
        let narrow = CoreTextMetrics.totalHeight(content: "This is a long text that should wrap", fontSize: 48, width: 320)
        XCTAssertGreaterThan(narrow, wide)
    }
}
