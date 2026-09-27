import XCTest
@testable import InstantTranslate

final class PanelMinimumSizeTests: XCTestCase {
    /// Pickers 180 + arrow 16 + 180 + 2 gaps of 6 = 388; + 6 + button 82 + 24 = 500.
    private func metrics(content: CGFloat = 331, input: CGFloat = 80, output: CGFloat = 80,
                         safeTop: CGFloat = 32) -> PanelMinimumSize.Metrics {
        .init(contentHeight: content, inputHeight: input, outputHeight: output,
              sourcePickerWidth: 180, arrowWidth: 16, targetPickerWidth: 180, buttonWidth: 82,
              safeAreaTop: safeTop)
    }

    // MARK: - compute: height

    func testAtMinimumTheLayoutIsTheMinimum() {
        // Fields at their 80 pt minimum: nothing to subtract, the title bar is added.
        XCTAssertEqual(PanelMinimumSize.compute(metrics()), CGSize(width: 500, height: 363))
    }

    func testStretchedFieldsAreSubtracted() {
        let tall = metrics(content: 331 + 120 + 200, input: 200, output: 280)
        XCTAssertEqual(PanelMinimumSize.compute(tall)?.height, 363)
    }

    func testExtraContentRaisesTheMinimum() {
        // A failure block appearing adds its height to the minimum.
        XCTAssertEqual(PanelMinimumSize.compute(metrics(content: 331 + 60))?.height, 423)
    }

    func testTheMinimumDoesNotGrowWithThePanel() {
        // The runaway this type once had: anything stretchy must cancel out, or
        // growing the panel to its minimum raises the minimum again.
        let small = PanelMinimumSize.compute(metrics())
        let large = PanelMinimumSize.compute(metrics(content: 331 + 900, input: 580, output: 480))
        XCTAssertEqual(small?.height, large?.height)
    }

    // MARK: - compute: width

    func testWidthIsPickersArrowButtonAndPadding() {
        XCTAssertEqual(PanelMinimumSize.compute(metrics())?.width, 500)
    }

    func testFractionsRoundUpSoNothingIsClipped() {
        var m = metrics(content: 330.2)
        m.sourcePickerWidth = 179.1
        XCTAssertEqual(PanelMinimumSize.compute(m), CGSize(width: 500, height: 363))
    }

    func testUnmeasuredLayoutGivesNoMinimum() {
        XCTAssertNil(PanelMinimumSize.compute(.init()))
    }
}
