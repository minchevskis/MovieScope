import Foundation

/// Native `URLSession`-based client for the TMDB v3 API.
///
/// - Authenticates with the API Read Access Token as a Bearer header.
/// - Adds `language=en-US` to every request.
/// - Maps HTTP status codes and transport failures to `APIError`.
/// - Retries an HTTP 429 once after `retryDelay`, then gives up.
public struct TMDBClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://api.themoviedb.org/3")!

    private let baseURL: URL
    private let transport: any HTTPTransport
    private let credentials: any CredentialProvider
    private let retryDelay: Duration
    private let sleeper: any Sleeper
    private let logsRequests: Bool

    public init(
        baseURL: URL = TMDBClient.defaultBaseURL,
        transport: any HTTPTransport,
        credentials: any CredentialProvider,
        retryDelay: Duration = .seconds(1),
        sleeper: any Sleeper = TaskSleeper(),
        logsRequests: Bool = false
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.credentials = credentials
        self.retryDelay = retryDelay
        self.sleeper = sleeper
        self.logsRequests = logsRequests
    }

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        guard let token = credentials.accessToken() else {
            throw APIError.missingCredentials
        }
        let request = try makeRequest(path: endpoint.path, queryItems: endpoint.queryItems, token: token)
        let data = try await perform(request, retriesLeft: 1)
        do {
            return try Self.makeDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Request building

    func makeRequest(path: String, queryItems: [URLQueryItem], token: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        components.path += path
        let allItems = queryItems + [URLQueryItem(name: "language", value: "en-US")]
        // Encode names and values strictly: URLComponents would leave "&", "=" and "+"
        // unescaped inside values, which corrupts queries like "Amélie & Co".
        components.percentEncodedQueryItems = allItems.map { item in
            URLQueryItem(name: Self.percentEncoded(item.name), value: item.value.map(Self.percentEncoded))
        }
        guard let url = components.url else {
            throw APIError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func percentEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? string
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Sending

    private func perform(_ request: URLRequest, retriesLeft: Int) async throws -> Data {
        let (data, response) = try await load(request)
        if logsRequests {
            Log.network.info("\(Log.requestLine(for: request, status: response.statusCode), privacy: .public)")
        }

        switch response.statusCode {
        case 200..<300:
            return data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429 where retriesLeft > 0:
            try await wait(retryDelay)
            return try await perform(request, retriesLeft: retriesLeft - 1)
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.server(status: response.statusCode)
        }
    }

    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.data(for: request)
        } catch {
            throw APIError(error)
        }
    }

    private func wait(_ duration: Duration) async throws {
        do {
            try await sleeper.sleep(for: duration)
        } catch {
            throw APIError(error)
        }
    }
}
