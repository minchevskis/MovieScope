import SwiftUI

/// Full-screen loading state.
struct LoadingStateView: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(AccessibilityID.State.loading)
    }
}

/// Full-screen error with a retry action.
struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.State.retryButton)
        }
        .accessibilityIdentifier(AccessibilityID.State.error)
    }
}
