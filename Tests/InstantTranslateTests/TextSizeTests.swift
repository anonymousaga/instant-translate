import XCTest
@testable import InstantTranslate

final class TextSizeTests: XCTestCase {
    // MARK: - next(from:_:)

    func testStepsUpAndDownFromTheBodySize() {
        XCTAssertEqual(TextSize.next(from: 13, .larger), 14)
        XCTAssertEqual(TextSize.next(from: 13, .smaller), 12)
    }

    func testStepsWidenAsTheSizeGrows() {
        XCTAssertEqual(TextSize.next(from: 14, .larger), 16)
        XCTAssertEqual(TextSize.next(from: 20, .larger), 24)
        XCTAssertEqual(TextSize.next(from: 24, .smaller), 20)
    }

    func testOffLadderSizeStepsToTheNeighbouringEntries() {
        // A system body size that is not on the ladder must still move both ways.
        XCTAssertEqual(TextSize.next(from: 13.5, .larger), 14)
        XCTAssertEqual(TextSize.next(from: 13.5, .smaller), 13)
    }

    func testEndsOfTheLadderDoNothing() {
        XCTAssertNil(TextSize.next(from: 28, .larger))
        XCTAssertNil(TextSize.next(from: 10, .smaller))
    }

    func testLargestSizeIsAtLeastTwiceTheBodySize() {
        // Apple's Larger Text criteria: body text enlargeable to at least 200%.
        XCTAssertGreaterThanOrEqual(TextSize.ladder.last! / 13, 2)
    }

    func testLadderIsStrictlyIncreasing() {
        XCTAssertEqual(TextSize.ladder, TextSize.ladder.sorted())
        XCTAssertEqual(Set(TextSize.ladder).count, TextSize.ladder.count)
    }

    // MARK: - effective(preference:body:)

    func testNoPreferenceUsesTheBodySize() {
        XCTAssertEqual(TextSize.effective(preference: nil, body: 13), 13)
        XCTAssertEqual(TextSize.effective(preference: nil, body: 15), 15)
    }

    func testPreferenceWinsOverTheBodySize() {
        XCTAssertEqual(TextSize.effective(preference: 18, body: 13), 18)
    }

    func testOutOfRangePreferenceIsClamped() {
        XCTAssertEqual(TextSize.effective(preference: 500, body: 13), 28)
        XCTAssertEqual(TextSize.effective(preference: 1, body: 13), 10)
        XCTAssertEqual(TextSize.effective(preference: .nan, body: 13), 13)
    }
}
