//  Unit tests for ScriptImporter — format detection, memory import, error descriptions
//  ticiqiTests

import XCTest
@testable import ticiqi

final class ScriptImporterTests: XCTestCase {

    // MARK: - detectFormat

    func testDetectTxt() {
        let url = URL(fileURLWithPath: "/test/file.txt")
        XCTAssertEqual(ScriptImporter.detectFormat(url: url), .txt)
    }

    func testDetectMarkdown() {
        let url = URL(fileURLWithPath: "/test/file.md")
        XCTAssertEqual(ScriptImporter.detectFormat(url: url), .markdown)
    }

    func testDetectMarkdownLong() {
        let url = URL(fileURLWithPath: "/test/file.markdown")
        XCTAssertEqual(ScriptImporter.detectFormat(url: url), .markdown)
    }

    func testDetectUnknownDefaultsToTxt() {
        let url = URL(fileURLWithPath: "/test/file.rtf")
        XCTAssertEqual(ScriptImporter.detectFormat(url: url), .txt)
    }

    func testDetectCaseInsensitive() {
        let url = URL(fileURLWithPath: "/test/file.MD")
        XCTAssertEqual(ScriptImporter.detectFormat(url: url), .markdown)
    }

    // MARK: - import(content:title:)

    func testImportContentCreatesDocument() {
        let doc = ScriptImporter.import(content: "Hello\nWorld", title: "My Script")
        XCTAssertEqual(doc.title, "My Script")
        XCTAssertEqual(doc.rawContent, "Hello\nWorld")
        XCTAssertEqual(doc.paragraphs.count, 2)
    }

    func testImportContentDefaultTitle() {
        let doc = ScriptImporter.import(content: "Text")
        XCTAssertEqual(doc.title, "未命名文稿")
    }

    // MARK: - ScriptImportError descriptions

    func testAccessDeniedDescription() {
        let error = ScriptImportError.accessDenied
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("无法访问"))
    }

    func testReadFailedDescription() {
        let error = ScriptImportError.readFailed("disk error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("disk error"))
    }

    func testEmptyFileDescription() {
        let error = ScriptImportError.emptyFile
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("为空"))
    }
}
