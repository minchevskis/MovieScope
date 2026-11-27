import Foundation

/// Every failure the networking layer can surface. Callers switch over these
/// cases instead of inspecting raw `URLError`s or status codes.
public enum APIError: Error, Equatable, Sendable {
    /// No token is configured; no request was sent.
    case missingCredentials
    /// TMDB rejected the token (HTTP 401).
    case unauthorized
    case notFound
    /// HTTP 429 persisted after one retry.
    case rateLimited
    case server(status: Int)
    case decoding(String)
    case transport(URLError.Code)
    case cancelled
    case invalidRequest
    case invalidResponse
}

extension APIError {
    /// Normalizes any error thrown while loading into an `APIError`.
    public init(_ error: any Error) {
        switch error {
        case let apiError as APIError:
            self = apiError
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            self = urlError.code == .cancelled ? .cancelled : .transport(urlError.code)
        default:
            self = .transport(.unknown)
        }
    }
}
