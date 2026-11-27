import Foundation

/// Supplies the TMDB API Read Access Token. Implementations return `nil` for a
/// missing, empty or whitespace-only value.
public protocol CredentialProvider: Sendable {
    func accessToken() -> String?
}

/// Reads the token from the process environment. The app only uses this in Dev
/// builds, where an Xcode scheme can set `TMDB_ACCESS_TOKEN`.
public struct EnvironmentCredentialProvider: CredentialProvider {
    private let token: String?

    public init(
        key: String = "TMDB_ACCESS_TOKEN",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        token = environment[key].trimmedNonEmpty
    }

    public func accessToken() -> String? { token }
}

/// Reads the token injected into Info.plist at build time from the gitignored
/// `Config/Secrets.xcconfig`. Note: anything embedded in an app bundle can be
/// extracted; a backend proxy is the only way to keep a key truly secret.
public struct BundleCredentialProvider: CredentialProvider {
    private let token: String?

    public init(bundle: Bundle = .main, key: String = "TMDBAccessToken") {
        token = (bundle.object(forInfoDictionaryKey: key) as? String).trimmedNonEmpty
    }

    public func accessToken() -> String? { token }
}

/// A fixed token, used for fixture mode and tests.
public struct StaticCredentialProvider: CredentialProvider {
    private let token: String?

    public init(_ token: String?) {
        self.token = token.trimmedNonEmpty
    }

    public func accessToken() -> String? { token }
}

/// Asks each provider in order and returns the first usable token.
public struct CredentialChain: CredentialProvider {
    private let providers: [any CredentialProvider]

    public init(_ providers: [any CredentialProvider]) {
        self.providers = providers
    }

    public func accessToken() -> String? {
        for provider in providers {
            if let token = provider.accessToken() { return token }
        }
        return nil
    }
}

extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
