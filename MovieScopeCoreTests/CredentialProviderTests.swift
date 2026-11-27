@testable import MovieScopeCore
import XCTest

final class CredentialProviderTests: XCTestCase {
    func test_chain_prefersEnvironment_thenBundle() {
        let environment = EnvironmentCredentialProvider(environment: ["TMDB_ACCESS_TOKEN": "from-env"])
        let fallback = StaticCredentialProvider("from-bundle")

        XCTAssertEqual(CredentialChain([environment, fallback]).accessToken(), "from-env")
        XCTAssertEqual(
            CredentialChain([EnvironmentCredentialProvider(environment: [:]), fallback]).accessToken(),
            "from-bundle"
        )
    }

    func test_chain_treatsEmptyAndWhitespaceAsMissing() {
        let chain = CredentialChain([
            EnvironmentCredentialProvider(environment: ["TMDB_ACCESS_TOKEN": "   "]),
            StaticCredentialProvider(""),
            StaticCredentialProvider("\n")
        ])

        XCTAssertNil(chain.accessToken())
    }

    func test_static_trimsSurroundingWhitespace() {
        XCTAssertEqual(StaticCredentialProvider("  abc \n").accessToken(), "abc")
    }

    func test_bundle_withoutKey_returnsNil() {
        let provider = BundleCredentialProvider(bundle: Bundle(for: CredentialProviderTests.self))

        XCTAssertNil(provider.accessToken())
    }
}
