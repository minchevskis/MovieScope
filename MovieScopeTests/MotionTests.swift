@testable import MovieScope
import SwiftUI
import XCTest

final class MotionTests: XCTestCase {
    func test_pressedCard_shrinksSlightly() {
        let appearance = Motion.pressedAppearance(isPressed: true, reduceMotion: false)

        XCTAssertEqual(appearance, PressedAppearance(transform: CGAffineTransform(scaleX: 0.97, y: 0.97), alpha: 1))
    }

    func test_pressedCard_withReduceMotion_dimsInsteadOfMoving() {
        let appearance = Motion.pressedAppearance(isPressed: true, reduceMotion: true)

        XCTAssertEqual(appearance.transform, .identity)
        XCTAssertLessThan(appearance.alpha, 1)
    }

    func test_releasedCard_isUnchanged() {
        for reduceMotion in [false, true] {
            XCTAssertEqual(
                Motion.pressedAppearance(isPressed: false, reduceMotion: reduceMotion),
                PressedAppearance(transform: .identity, alpha: 1)
            )
        }
    }

    func test_animation_withReduceMotion_isDropped() {
        XCTAssertNil(Motion.animation(.snappy, reduceMotion: true))
        XCTAssertNotNil(Motion.animation(.snappy, reduceMotion: false))
    }
}
