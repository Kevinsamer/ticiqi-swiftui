//  Unit tests for PrompterSettings — Codable round-trip, defaults
//  ticiqiTests

import XCTest
@testable import ticiqi

final class PrompterSettingsTests: XCTestCase {

    // MARK: - Default values

    func testDefaultValues() {
        let settings = PrompterSettings()
        XCTAssertEqual(settings.defaultSpeed, 30.0)
        XCTAssertEqual(settings.fontSize, 48.0)
        XCTAssertEqual(settings.scrollDirection, .up)
        XCTAssertEqual(settings.textColorHex, "#FFFFFF")
        XCTAssertEqual(settings.backgroundColor, .black)
        XCTAssertFalse(settings.mirrorEnabled)
        XCTAssertTrue(settings.focusLineEnabled)
        XCTAssertTrue(settings.autoStartServer)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        var original = PrompterSettings()
        original.defaultSpeed = 50
        original.fontSize = 72
        original.scrollDirection = .down
        original.textColorHex = "#00FF00"
        original.backgroundColor = .darkGray
        original.mirrorEnabled = true
        original.focusLineEnabled = false
        original.autoStartServer = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: data)

        XCTAssertEqual(decoded.defaultSpeed, 50)
        XCTAssertEqual(decoded.fontSize, 72)
        XCTAssertEqual(decoded.scrollDirection, .down)
        XCTAssertEqual(decoded.textColorHex, "#00FF00")
        XCTAssertEqual(decoded.backgroundColor, .darkGray)
        XCTAssertTrue(decoded.mirrorEnabled)
        XCTAssertFalse(decoded.focusLineEnabled)
        XCTAssertFalse(decoded.autoStartServer)
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = PrompterSettings()
        let b = PrompterSettings()
        XCTAssertEqual(a, b)
    }

    func testNotEquatableWhenDifferent() {
        var a = PrompterSettings()
        let b = PrompterSettings()
        a.defaultSpeed = 99
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Text color hex

    func testTextColorHexDefault() {
        let settings = PrompterSettings()
        XCTAssertEqual(settings.textColorHex, "#FFFFFF")
    }

    func testTextColorHexRoundTrip() {
        var settings = PrompterSettings()
        settings.textColorHex = "#FF0000"
        XCTAssertEqual(settings.textColorHex, "#FF0000")
    }

    // MARK: - BackgroundOption

    func testBackgroundOptionAllCases() {
        XCTAssertEqual(BackgroundOption.allCases.count, 2)
    }

    func testBackgroundOptionRawValues() {
        XCTAssertEqual(BackgroundOption.black.rawValue, "black")
        XCTAssertEqual(BackgroundOption.darkGray.rawValue, "darkGray")
    }

    // MARK: - ScrollDirection

    func testScrollDirectionRawValues() {
        XCTAssertEqual(ScrollDirection.up.rawValue, "up")
        XCTAssertEqual(ScrollDirection.down.rawValue, "down")
    }
}
