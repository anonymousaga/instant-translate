import CoreGraphics

/// The smallest the translation panel may be, derived from its content as actually
/// laid out at the current size.
///
/// Why not let `NSHostingView` report the minimum (`sizingOptions: .minSize`): that
/// measures the content under a 0 × 0 proposal, which text cannot answer honestly —
/// a single-line text reports zero height (so the minimum came out too short and the
/// bottom margin was eaten), and a text held at its natural height wraps one
/// character per line (so the minimum shot up to 646 pt). The failure block is
/// multi-line by nature, so no per-text fix could cover it. Measuring the real
/// layout has neither problem. Pure, so the arithmetic is unit-tested.
struct PanelMinimumSize: Equatable {
    /// Laid-out sizes, as reported by `PanelView`.
    struct Metrics: Equatable {
        /// The content stack including its padding. A stack that can't shrink
        /// further reports its needed height even when the panel is smaller.
        var contentHeight: CGFloat = 0
        /// The two stretchy fields, each at least `fieldMinimum` tall.
        var inputHeight: CGFloat = 0
        var outputHeight: CGFloat = 0
        /// The picker row's incompressible parts.
        var sourcePickerWidth: CGFloat = 0
        var arrowWidth: CGFloat = 0
        var targetPickerWidth: CGFloat = 0
        var buttonWidth: CGFloat = 0
        /// The transparent title bar the content sits below.
        var safeAreaTop: CGFloat = 0
    }

    /// Minimum height of each of the two text fields (`PanelView`).
    static let fieldMinimum: CGFloat = 80
    /// Leading + trailing padding of the content stack (`PanelView`).
    static let horizontalPadding: CGFloat = 24
    /// Gap between items in the picker group, and between the group and the button.
    static let itemSpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 6
    /// Gap between a picker and the hint line under it, and the hint's indent from
    /// the picker's left edge. Tuned by eye: 2 pt + a tenth of a caption line down,
    /// 4 pt + half a caption character (10 pt) in.
    static let hintSpacing: CGFloat = 3.3
    static let hintIndent: CGFloat = 9
    /// Fixed blank space between the hint line and the status row — about half a
    /// line, so the hints read as belonging to the pickers, not to the status.
    static let hintGap: CGFloat = 8

    /// The pickers and the arrow between them.
    static func pickerGroupWidth(_ m: Metrics) -> CGFloat {
        m.sourcePickerWidth + m.arrowWidth + m.targetPickerWidth + 2 * itemSpacing
    }

    /// The minimum content size of the panel window, or `nil` until the layout has
    /// been measured.
    ///
    /// Height: the content as laid out, minus however far each field is stretched
    /// beyond its minimum, plus the title bar. Width: the pickers, the arrow and the
    /// button, which never compress, plus the padding.
    /// Anything else that appears (the failure block, say) is included by
    /// construction.
    ///
    /// Everything subtracted must be everything that stretches: a stretchy view
    /// left out makes the minimum grow with the panel, and growing the panel to its
    /// minimum then feeds on itself (a `Spacer` wrapped in a measuring modifier
    /// stretched vertically and drove the panel to the height of the screen).
    static func compute(_ m: Metrics) -> CGSize? {
        guard m.contentHeight > 0, m.sourcePickerWidth > 0, m.targetPickerWidth > 0 else { return nil }
        let stretch = max(0, m.inputHeight - fieldMinimum) + max(0, m.outputHeight - fieldMinimum)
        let height = m.contentHeight - stretch + m.safeAreaTop
        let width = pickerGroupWidth(m) + rowSpacing + m.buttonWidth + horizontalPadding
        return CGSize(width: width.rounded(.up), height: height.rounded(.up))
    }
}
