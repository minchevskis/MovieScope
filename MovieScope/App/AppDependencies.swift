import Foundation
import MovieScopeCore

/// Composition root: builds the object graph once at launch and hands each
/// screen only the protocols it needs.
@MainActor
final class AppDependencies {
    let environment: AppEnvironment
    let service: any TMDBService
    let imageProvider: ImageProvider
    let favorites: FavoritesModel
    let hasCredentials: Bool
    /// The tab screens' view models live as long as the app, so they are built
    /// here, once. Built in a view's initializer instead, they would be rebuilt
    /// (and thrown away) every time SwiftUI re-creates that view.
    let trending: TrendingViewModel
    let search: SearchViewModel

    init(environment: AppEnvironment, bundle: Bundle = .main) {
        self.environment = environment
        if environment.resetsState {
            Self.resetPersistentState()
        }

        let credentials: any CredentialProvider
        let apiTransport: any HTTPTransport
        let imageTransport: any HTTPTransport
        if environment.usesFixtures {
            let fixtures = FixtureTransport(
                bundle: bundle,
                failingOnce: environment.failsSecondTrendingPageOnce ? ["/3/trending/movie/week?page=2"] : []
            )
            credentials = StaticCredentialProvider(environment.forcesMissingToken ? nil : "fixture-token")
            apiTransport = fixtures
            imageTransport = fixtures
        } else {
            credentials = environment.forcesMissingToken ? StaticCredentialProvider(nil) : Self.liveCredentials(bundle)
            apiTransport = URLSessionTransport.api
            imageTransport = URLSessionTransport.images
        }

        let client = TMDBClient(
            transport: apiTransport,
            credentials: credentials,
            logsRequests: environment.logLevel == "debug"
        )
        service = client
        hasCredentials = credentials.accessToken() != nil
        trending = TrendingViewModel(service: client)
        search = SearchViewModel(service: client)
        favorites = FavoritesModel(
            store: FavoritesStore(fileURL: Self.supportDirectory.appendingPathComponent("favorites.json"))
        )
        imageProvider = ImageProvider(
            pipeline: ImagePipeline(transport: imageTransport),
            configurationStore: ImageConfigurationStore(
                service: client,
                fileURL: Self.supportDirectory.appendingPathComponent("image-configuration.json")
            )
        )
    }

    /// The view model for a tapped title's details. Screens call this when the
    /// title is tapped, so each push builds exactly one.
    func makeDetails(for summary: MediaSummary) -> DetailsViewModel {
        DetailsViewModel(id: summary.id, placeholder: summary, service: service)
    }

    /// Dev builds also accept a token from the Xcode scheme's environment;
    /// release builds only read the value baked in from Secrets.xcconfig.
    private static func liveCredentials(_ bundle: Bundle) -> any CredentialProvider {
        #if DEBUG
        CredentialChain([EnvironmentCredentialProvider(), BundleCredentialProvider(bundle: bundle)])
        #else
        BundleCredentialProvider(bundle: bundle)
        #endif
    }

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MovieScope", isDirectory: true)
    }

    private static func resetPersistentState() {
        try? FileManager.default.removeItem(at: supportDirectory)
    }
}
