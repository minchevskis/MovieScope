import SwiftUI

extension View {
    /// Liquid Glass on iOS 26+, with a material background on iOS 18–25.
    /// The app supports iOS 18, so newer APIs are gated rather than required.
    @ViewBuilder
    func glassOrMaterial(in shape: some Shape = .capsule) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}
