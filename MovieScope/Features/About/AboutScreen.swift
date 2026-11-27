import SwiftUI

/// App information and the TMDB attribution required by TMDB's API terms.
struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss

    static let attribution =
        "This application uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB."

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TMDBLogo()
                        Text(Self.attribution)
                            .font(.callout)
                            .accessibilityIdentifier(AccessibilityID.About.attribution)
                    }
                    .padding(.vertical, 4)
                    if let url = URL(string: "https://www.themoviedb.org") {
                        Link("Visit The Movie Database", destination: url)
                    }
                } header: {
                    Text("Data source")
                }

                Section("App") {
                    LabeledContent("Version", value: Self.versionString)
                    LabeledContent("Environment", value: Self.environmentName)
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.About.screen)
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private static var environmentName: String {
        (Bundle.main.object(forInfoDictionaryKey: "MovieScopeEnvironment") as? String)?.capitalized ?? "-"
    }
}

/// The TMDB logo when the official asset is bundled; otherwise a wordmark.
private struct TMDBLogo: View {
    var body: some View {
        if UIImage(named: "TMDBLogo") != nil {
            Image("TMDBLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .accessibilityLabel("The Movie Database logo")
        } else {
            Text("TMDB")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.teal)
                .accessibilityLabel("The Movie Database")
        }
    }
}
