import SwiftUI

/// Shown instead of the app when no TMDB token is configured.
struct MissingTokenView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Add your TMDB token", systemImage: "key.horizontal")
        } description: {
            VStack(alignment: .leading, spacing: 8) {
                Text("MovieScope needs a TMDB API Read Access Token to load content.")
                Text("1. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig.")
                Text("2. Paste your token as the value of TMDB_ACCESS_TOKEN.")
                Text("3. Build and run again.")
            }
            .multilineTextAlignment(.leading)
        } actions: {
            if let url = URL(string: "https://www.themoviedb.org/settings/api") {
                Link("Get a token on themoviedb.org", destination: url)
            }
        }
        .accessibilityIdentifier(AccessibilityID.MissingToken.screen)
    }
}
