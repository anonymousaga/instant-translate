import CoreGraphics
import XCTest
@testable import InstantTranslate

final class WindowPlacementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testAFrameInsideTheScreenIsUntouched() {
        let f = CGRect(x: 100, y: 100, width: 400, height: 300)
        XCTAssertEqual(WindowPlacement.clamped(f, into: screen), f)
    }

    func testGrowingPastTheRightEdgeMovesLeft() {
        // A 380 pt panel at the right edge grown to 574 pt, keeping its left edge.
        let grown = CGRect(x: 1440 - 8 - 380, y: 400, width: 574, height: 363)
        XCTAssertEqual(WindowPlacement.clamped(grown, into: screen).maxX, 1440 - 8)
    }

    func testGrowingPastTheBottomMovesUp() {
        let grown = CGRect(x: 100, y: -23, width: 574, height: 363)
        XCTAssertEqual(WindowPlacement.clamped(grown, into: screen).minY, 8)
    }

    func testTooLargeKeepsTheTopLeftInView() {
        let huge = CGRect(x: 500, y: -500, width: 2000, height: 2000)
        let c = WindowPlacement.clamped(huge, into: screen)
        XCTAssertEqual(c.minX, 8)
        XCTAssertEqual(c.maxY, 900 - 8)
    }

    func testRespectsAnOffsetScreen() {
        // A secondary display to the left of the main one.
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let f = CGRect(x: -100, y: 500, width: 574, height: 363)
        XCTAssertEqual(WindowPlacement.clamped(f, into: left).maxX, -8)
    }
}
