//  Unit tests for Paragraph model and classify logic
//  ticiqiTests

import XCTest
@testable import ticiqi

final class ParagraphTests: XCTestCase {

    // MARK: - Heading classification

    func testH1() {
        XCTAssertEqual(Paragraph.classify("# Title"), .heading)
    }

    func testH2() {
        XCTAssertEqual(Paragraph.classify("## Subtitle"), .heading)
    }

    func testH3() {
        XCTAssertEqual(Paragraph.classify("### Section"), .heading)
    }

    func testH4NotHeading() {
        // Only #, ##, ### are classified as heading
        XCTAssertEqual(Paragraph.classify("#### Deep"), .normal)
    }

    func testNormalText() {
        XCTAssertEqual(Paragraph.classify("Just some text"), .normal)
    }

    func testHashWithoutSpace() {
        XCTAssertEqual(Paragraph.classify("#NoSpace"), .normal)
    }

    func testLeadingWhitespaceThenHeading() {
        XCTAssertEqual(Paragraph.classify("   # Indented"), .heading)
    }

    func testEmptyString() {
        XCTAssertEqual(Paragraph.classify(""), .normal)
    }

    func testOnlySpaces() {
        XCTAssertEqual(Paragraph.classify("   "), .normal)
    }

    // MARK: - Identifiable

    func testUniqueIDs() {
        let a = Paragraph(text: "A", characterRange: "".startIndex..<"".endIndex,
                          characterOffset: 0, markerType: .normal)
        let b = Paragraph(text: "B", characterRange: "".startIndex..<"".endIndex,
                          characterOffset: 1, markerType: .normal)
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - ParagraphMarker raw values

    func testMarkerRawValues() {
        XCTAssertEqual(ParagraphMarker.heading.rawValue, "heading")
        XCTAssertEqual(ParagraphMarker.normal.rawValue, "normal")
    }

    func testMarkerCaseIterable() {
        XCTAssertEqual(ParagraphMarker.allCases.count, 2)
    }
}
