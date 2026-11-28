import CoreGraphics
import SwiftUI

/// How a pressed card looks.
nonisolated struct PressedAppearance: Equatable {
    let transform: CGAffineTransform
    let alpha: CGFloat
}

/// Animation choices that respect the Reduce Motion setting: movement
/// (scaling, bouncing, expanding) is dropped or replaced by a dim, while
/// cross-fades stay, as Apple's Human Interface Guidelines suggest.
nonisolated enum Motion {
    /// `animation`, or none when Reduce Motion is on.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// Feedback for a pressed card: a slight shrink, or a dim with Reduce Motion.
    static func pressedAppearance(isPressed: Bool, reduceMotion: Bool) -> PressedAppearance {
        guard isPressed else { return PressedAppearance(transform: .identity, alpha: 1) }
        return reduceMotion
            ? PressedAppearance(transform: .identity, alpha: 0.7)
            : PressedAppearance(transform: CGAffineTransform(scaleX: 0.97, y: 0.97), alpha: 1)
    }
}
