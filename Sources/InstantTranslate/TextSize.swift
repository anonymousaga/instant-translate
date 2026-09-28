import Foundation

/// The size of the panel's *content* text — the input, its placeholder and the
/// translation. Controls keep their sizes ().
///
/// ⌘+ / ⌘− step through a fixed ladder that widens as it grows; ⌘0 drops the
/// preference, which means "use the system body size". Pure, so the stepping
/// rules are unit-tested without a view.
enum TextSize {
    /// Point sizes ⌘+ / ⌘− step through. 28 pt is 215% of the 13 pt body size —
    /// past the 200% Apple's Larger Text criteria ask for.
    static let ladder: [Double] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28]

    enum Step { case larger, smaller }

    /// The next ladder size strictly larger / smaller than `current`, or `nil` at
    /// that end of the ladder. "Strictly" is what lets a system body size that is
    /// not on the ladder still step cleanly in both directions.
    static func next(from current: Double, _ step: Step) -> Double? {
        switch step {
        case .larger:  ladder.first { $0 > current }
        case .smaller: ladder.last { $0 < current }
        }
    }

    /// The size to draw at: the stored preference, else the system body size. A
    /// stored value outside the ladder's range (a hand-edited default) is clamped,
    /// so the panel can never become unreadable or unusable.
    static func effective(preference: Double?, body: Double) -> Double {
        guard let preference, preference.isFinite else { return body }
        return min(max(preference, ladder.first!), ladder.last!)
    }
}
