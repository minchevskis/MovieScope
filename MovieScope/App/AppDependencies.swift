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
            apiTransport = URLSessionTransport(session: .api)
            imageTransport = URLSessionTransport(session: .images)
        }

        let client = TMDBClient(
            transport: apiTransport,
            credentials: credentials,
            logsRequests: environment.logLevel == "debug"
        )
        service = client
        hasCredentials = credentials.accessToken() != nil
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
