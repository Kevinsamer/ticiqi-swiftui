//  Unit tests for ScriptDocument — paragraph parsing, normalization, updateContent
//  ticiqiTests

import XCTest
@testable import ticiqi

final class ScriptDocumentTests: XCTestCase {

    // MARK: - Init

    func testInitEmpty() {
        let doc = ScriptDocument()
        XCTAssertEqual(doc.title, "")
        XCTAssertEqual(doc.rawContent, "")
        XCTAssertTrue(doc.paragraphs.isEmpty)
        XCTAssertEqual(doc.totalCharacterCount, 0)
    }

    func testInitWithTitleAndContent() {
        let doc = ScriptDocument(title: "Test", content: "Hello\nWorld")
        XCTAssertEqual(doc.title, "Test")
        XCTAssertEqual(doc.rawContent, "Hello\nWorld")
        XCTAssertEqual(doc.paragraphs.count, 2)
        XCTAssertEqual(doc.totalCharacterCount, 11)
    }

    // MARK: - Line ending normalization

    func testNormalizeCRLF() {
        let doc = ScriptDocument(title: "T", content: "A\r\nB")
        XCTAssertEqual(doc.rawContent, "A\nB")
        XCTAssertEqual(doc.paragraphs.count, 2)
    }

    func testNormalizeCR() {
        let doc = ScriptDocument(title: "T", content: "A\rB")
        XCTAssertEqual(doc.rawContent, "A\nB")
        XCTAssertEqual(doc.paragraphs.count, 2)
    }

    func testNormalizeMixedLineEndings() {
        let doc = ScriptDocument(title: "T", content: "A\r\nB\nC\rD")
        XCTAssertEqual(doc.rawContent, "A\nB\nC\nD")
        XCTAssertEqual(doc.paragraphs.count, 4)
    }

    // MARK: - Paragraph parsing

    func testSingleLine() {
        let doc = ScriptDocument(title: "T", content: "Hello")
        XCTAssertEqual(doc.paragraphs.count, 1)
        XCTAssertEqual(doc.paragraphs[0].text, "Hello")
        XCTAssertEqual(doc.paragraphs[0].characterOffset, 0)
    }

    func testMultipleLines() {
        let doc = ScriptDocument(title: "T", content: "Line1\nLine2\nLine3")
        XCTAssertEqual(doc.paragraphs.count, 3)
        XCTAssertEqual(doc.paragraphs[0].text, "Line1")
        XCTAssertEqual(doc.paragraphs[1].text, "Line2")
        XCTAssertEqual(doc.paragraphs[2].text, "Line3")
    }

    func testEmptyLinesSkipped() {
        let doc = ScriptDocument(title: "T", content: "A\n\n\nB")
        XCTAssertEqual(doc.paragraphs.count, 2)
        XCTAssertEqual(doc.paragraphs[0].text, "A")
        XCTAssertEqual(doc.paragraphs[1].text, "B")
    }

    func testTrailingNewline() {
        let doc = ScriptDocument(title: "T", content: "Hello\n")
        XCTAssertEqual(doc.paragraphs.count, 1)
        XCTAssertEqual(doc.paragraphs[0].text, "Hello")
    }

    func testCharacterOffsetPrecomputed() {
        let doc = ScriptDocument(title: "T", content: "AB\nCDE")
        XCTAssertEqual(doc.paragraphs[0].characterOffset, 0)
        XCTAssertEqual(doc.paragraphs[1].characterOffset, 3) // "AB\n" = 3 chars
    }

    // MARK: - Markdown heading classification

    func testHeadingClassification() {
        let doc = ScriptDocument(title: "T", content: "# Title\nNormal\n## Sub\n### Deep")
        XCTAssertEqual(doc.paragraphs[0].markerType, .heading)
        XCTAssertEqual(doc.paragraphs[1].markerType, .normal)
        XCTAssertEqual(doc.paragraphs[2].markerType, .heading)
        XCTAssertEqual(doc.paragraphs[3].markerType, .heading)
    }

    // MARK: - updateContent

    func testUpdateContent() {
        var doc = ScriptDocument(title: "T", content: "Old")
        XCTAssertEqual(doc.paragraphs.count, 1)

        doc.updateContent("New\nContent")
        XCTAssertEqual(doc.rawContent, "New\nContent")
        XCTAssertEqual(doc.paragraphs.count, 2)
        XCTAssertEqual(doc.totalCharacterCount, 11)
    }

    func testUpdateContentPreservesTitle() {
        var doc = ScriptDocument(title: "MyTitle", content: "Old")
        doc.updateContent("New")
        XCTAssertEqual(doc.title, "MyTitle")
    }

    // MARK: - ParagraphCount computed property

    func testParagraphCount() {
        let doc = ScriptDocument(title: "T", content: "A\nB\nC")
        XCTAssertEqual(doc.paragraphCount, 3)
        XCTAssertEqual(doc.paragraphCount, doc.paragraphs.count)
    }
}
