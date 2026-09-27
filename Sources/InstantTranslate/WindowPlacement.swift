import CoreGraphics

/// Keeping a window on screen after it was resized in code. Pure, so it is tested.
enum WindowPlacement {
    /// `frame` moved (not resized) so it lies inside `visible` with `margin` to spare
    /// on every side. A frame larger than the space keeps its top-left corner in view.
    ///
    /// Why: growing a window to a new minimum keeps its top edge, so the extra width
    /// goes right and the extra height down — past the screen edge when the window
    /// sat near it, and `setFrame(_:display:)` does not constrain to the screen.
    static func clamped(_ frame: CGRect, into visible: CGRect, margin: CGFloat = 8) -> CGRect {
        var f = frame
        f.origin.x = max(min(f.origin.x, visible.maxX - margin - f.width), visible.minX + margin)
        f.origin.y = min(max(f.origin.y, visible.minY + margin), visible.maxY - margin - f.height)
        return f
    }
}
