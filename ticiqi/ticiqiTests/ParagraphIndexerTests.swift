//  Unit tests for ParagraphIndexer — index building, heading filter, progress estimation
//  ticiqiTests

import XCTest
@testable import ticiqi

final class ParagraphIndexerTests: XCTestCase {

    private func makeDocument(_ content: String) -> ScriptDocument {
        ScriptDocument(title: "Test", content: content)
    }

    // MARK: - index()

    func testIndexReturnsCorrectCount() {
        let doc = makeDocument("A\nB\nC")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        XCTAssertEqual(positions.count, 3)
    }

    func testIndexEmptyDocument() {
        let doc = ScriptDocument()
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        XCTAssertTrue(positions.isEmpty)
    }

    func testIndexFirstParagraphProgressIsZero() {
        let doc = makeDocument("First\nSecond")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        XCTAssertEqual(positions.first?.estimatedProgress, 0.0)
    }

    func testIndexProgressIsMonotonicallyIncreasing() {
        let doc = makeDocument("A\nB\nC\nD\nE")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        for i in 1..<positions.count {
            XCTAssertGreaterThan(positions[i].estimatedProgress, positions[i - 1].estimatedProgress)
        }
    }

    func testIndexProgressNeverExceedsOne() {
        let doc = makeDocument("A\nB\nC")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        for pos in positions {
            XCTAssertLessThanOrEqual(pos.estimatedProgress, 1.0)
            XCTAssertGreaterThanOrEqual(pos.estimatedProgress, 0.0)
        }
    }

    func testIndexIDMatchesParagraphIndex() {
        let doc = makeDocument("A\nB\nC")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        for (i, pos) in positions.enumerated() {
            XCTAssertEqual(pos.id, i)
            XCTAssertEqual(pos.paragraphIndex, i)
        }
    }

    // MARK: - headingPositions()

    func testHeadingPositionsFiltersCorrectly() {
        let doc = makeDocument("# Title\nNormal\n## Sub\nPlain")
        let all = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        let headings = ParagraphIndexer.headingPositions(from: all)
        XCTAssertEqual(headings.count, 2)
        XCTAssertEqual(headings[0].paragraph.text, "# Title")
        XCTAssertEqual(headings[1].paragraph.text, "## Sub")
    }

    func testHeadingPositionsEmptyWhenNoHeadings() {
        let doc = makeDocument("Plain text\nNo headings")
        let all = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        let headings = ParagraphIndexer.headingPositions(from: all)
        XCTAssertTrue(headings.isEmpty)
    }

    // MARK: - ParagraphPosition.displayLabel

    func testDisplayLabelHeadingRemovesHashPrefix() {
        let doc = makeDocument("# Hello")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        let label = positions[0].displayLabel
        XCTAssertFalse(label.hasPrefix("#"))
        XCTAssertTrue(label.contains("Hello"))
    }

    func testDisplayLabelNormalHasIndent() {
        let doc = makeDocument("Normal text")
        let positions = ParagraphIndexer.index(document: doc, fontSize: 48, width: 768)
        let label = positions[0].displayLabel
        XCTAssertTrue(label.hasPrefix("  "))
    }
}
