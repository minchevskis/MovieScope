import SwiftUI

@main
struct MovieScopeApp: App {
    var body: some Scene {
        WindowGroup {
            Text("MovieScope")
                .accessibilityIdentifier(AccessibilityID.Root.placeholder)
        }
    }
}
