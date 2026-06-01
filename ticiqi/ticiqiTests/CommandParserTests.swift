//  Unit tests for CommandParser — JSON command parsing, boundary values
//  ticiqiTests

import XCTest
@testable import ticiqi

final class CommandParserTests: XCTestCase {

    // MARK: - Simple commands (no value)

    func testParsePlay() {
        let cmd = CommandParser.parse(from: #"{"action":"play"}"#)
        assertCommandIsPlay(cmd)
    }

    func testParsePause() {
        let cmd = CommandParser.parse(from: #"{"action":"pause"}"#)
        guard case .pause = cmd else { return XCTFail("Expected .pause") }
    }

    func testParseMirror() {
        let cmd = CommandParser.parse(from: #"{"action":"mirror"}"#)
        guard case .mirror = cmd else { return XCTFail("Expected .mirror") }
    }

    func testParseFocusLine() {
        let cmd = CommandParser.parse(from: #"{"action":"focusLine"}"#)
        guard case .focusLine = cmd else { return XCTFail("Expected .focusLine") }
    }

    func testParseScrollDirection() {
        let cmd = CommandParser.parse(from: #"{"action":"scrollDirection"}"#)
        guard case .scrollDirection = cmd else { return XCTFail("Expected .scrollDirection") }
    }

    func testParsePing() {
        let cmd = CommandParser.parse(from: #"{"action":"ping"}"#)
        guard case .ping = cmd else { return XCTFail("Expected .ping") }
    }

    // MARK: - Commands with value

    func testParseSpeed() {
        let cmd = CommandParser.parse(from: #"{"action":"speed","value":45}"#)
        guard case .speed(let v) = cmd else { return XCTFail("Expected .speed") }
        XCTAssertEqual(v, 45)
    }

    func testParseFontSize() {
        let cmd = CommandParser.parse(from: #"{"action":"fontSize","value":72}"#)
        guard case .fontSize(let v) = cmd else { return XCTFail("Expected .fontSize") }
        XCTAssertEqual(v, 72)
    }

    func testParseSeek() {
        let cmd = CommandParser.parse(from: #"{"action":"seek","value":0.5}"#)
        guard case .seek(let v) = cmd else { return XCTFail("Expected .seek") }
        XCTAssertEqual(v, 0.5, accuracy: 0.001)
    }

    func testParseUpdateText() {
        let cmd = CommandParser.parse(from: #"{"action":"updateText","value":"Hello"}"#)
        guard case .updateText(let v) = cmd else { return XCTFail("Expected .updateText") }
        XCTAssertEqual(v, "Hello")
    }

    // MARK: - Seek clamping

    func testSeekClampedAboveOne() {
        let cmd = CommandParser.parse(from: #"{"action":"seek","value":1.5}"#)
        guard case .seek(let v) = cmd else { return XCTFail("Expected .seek") }
        XCTAssertEqual(v, 1.0, accuracy: 0.001)
    }

    func testSeekClampedBelowZero() {
        let cmd = CommandParser.parse(from: #"{"action":"seek","value":-0.3}"#)
        guard case .seek(let v) = cmd else { return XCTFail("Expected .seek") }
        XCTAssertEqual(v, 0.0, accuracy: 0.001)
    }

    // MARK: - Missing value returns nil

    func testSpeedWithoutValueReturnsNil() {
        let cmd = CommandParser.parse(from: #"{"action":"speed"}"#)
        XCTAssertNil(cmd)
    }

    func testFontSizeWithoutValueReturnsNil() {
        let cmd = CommandParser.parse(from: #"{"action":"fontSize"}"#)
        XCTAssertNil(cmd)
    }

    func testSeekWithoutValueReturnsNil() {
        let cmd = CommandParser.parse(from: #"{"action":"seek"}"#)
        XCTAssertNil(cmd)
    }

    func testUpdateTextWithoutValueReturnsNil() {
        let cmd = CommandParser.parse(from: #"{"action":"updateText"}"#)
        XCTAssertNil(cmd)
    }

    func testUpdateTextWithEmptyStringReturnsNil() {
        let cmd = CommandParser.parse(from: #"{"action":"updateText","value":"   "}"#)
        XCTAssertNil(cmd)
    }

    // MARK: - Invalid input

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(CommandParser.parse(from: "not json"))
    }

    func testMissingActionReturnsNil() {
        XCTAssertNil(CommandParser.parse(from: #"{"value":42}"#))
    }

    func testUnknownActionReturnsNil() {
        XCTAssertNil(CommandParser.parse(from: #"{"action":"unknown"}"#))
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(CommandParser.parse(from: ""))
    }

    // MARK: - Helper

    private func assertCommandIsPlay(_ cmd: ControlCommand?, file: StaticString = #file, line: UInt = #line) {
        guard case .play = cmd else {
            XCTFail("Expected .play", file: file, line: line)
            return
        }
    }
}
