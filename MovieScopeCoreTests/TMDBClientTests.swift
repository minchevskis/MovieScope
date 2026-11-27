import Foundation
@testable import MovieScopeCore
import XCTest

private struct Probe: Decodable, Sendable, Equatable {
    let ok: Bool
}

final class TMDBClientTests: XCTestCase {
    private let okBody = #"{"ok":true}"#

    // MARK: - Request building

    func test_send_buildsURLWithPathQueryAndLanguage() async throws {
        let transport = FakeTransport([.json(okBody)])
        let sut = makeSUT(transport: transport)

        _ = try await sut.send(Endpoint<Probe>(path: "/trending/movie/week", queryItems: [
            URLQueryItem(name: "page", value: "2")
        ]))

        let requests = await transport.requests
        let url = try XCTUnwrap(requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.themoviedb.org")
        XCTAssertEqual(components.path, "/3/trending/movie/week")
        XCTAssertEqual(components.queryItems, [
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "language", value: "en-US")
        ])
    }

    func test_send_percentEncodesUnicodeAndSymbols() async throws {
        let transport = FakeTransport([.json(okBody), .json(okBody)])
        let sut = makeSUT(transport: transport)

        _ = try await sut.send(Endpoint<Probe>(path: "/search/movie", queryItems: [
            URLQueryItem(name: "query", value: "Amélie & Co")
        ]))
        _ = try await sut.send(Endpoint<Probe>(path: "/search/tv", queryItems: [
            URLQueryItem(name: "query", value: "東京+1")
        ]))

        let urls = await transport.requests.compactMap(\.url?.absoluteString)
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls[0].contains("query=Am%C3%A9lie%20%26%20Co&"), urls[0])
        XCTAssertTrue(urls[1].contains("query=%E6%9D%B1%E4%BA%AC%2B1&"), urls[1])
    }

    func test_send_setsBearerAuthorizationHeader() async throws {
        let transport = FakeTransport([.json(okBody)])
        let sut = makeSUT(transport: transport, token: "token-123")

        _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))

        let header = await transport.requests.first?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(header, "Bearer token-123")
    }

    func test_send_withoutToken_throwsMissingCredentials_andSendsNothing() async {
        let transport = FakeTransport([.json(okBody)])
        let sut = makeSUT(transport: transport, token: nil)

        await assertThrows(APIError.missingCredentials) {
            _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    // MARK: - Status mapping

    func test_send_maps401ToUnauthorized() async {
        await assertStatus(401, throws: .unauthorized)
    }

    func test_send_maps404ToNotFound() async {
        await assertStatus(404, throws: .notFound)
    }

    func test_send_maps500ToServer() async {
        await assertStatus(500, throws: .server(status: 500))
    }

    func test_send_429_retriesOnceAfterDelay_thenSucceeds() async throws {
        let transport = FakeTransport([.json("{}", status: 429), .json(okBody)])
        let sleeper = RecordingSleeper()
        let sut = makeSUT(transport: transport, sleeper: sleeper)

        let probe = try await sut.send(Endpoint<Probe>(path: "/configuration"))

        XCTAssertEqual(probe, Probe(ok: true))
        let requestCount = await transport.requests.count
        let durations = await sleeper.durations
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(durations, [.seconds(1)])
    }

    func test_send_429Twice_throwsRateLimited() async {
        let transport = FakeTransport([.json("{}", status: 429), .json("{}", status: 429)])
        let sut = makeSUT(transport: transport)

        await assertThrows(APIError.rateLimited) {
            _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
        }
        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 2)
    }

    // MARK: - Decoding and transport errors

    func test_send_malformedJSON_throwsDecoding() async {
        let transport = FakeTransport([.json(#"{"ok":"#)])
        let sut = makeSUT(transport: transport)

        do {
            _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
            XCTFail("Expected a decoding error")
        } catch let APIError.decoding(message) {
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_send_whenTransportThrowsCancellation_throwsCancelled() async {
        for failure: any Error in [CancellationError(), URLError(.cancelled)] {
            let sut = makeSUT(transport: FakeTransport([.failure(failure)]))
            await assertThrows(APIError.cancelled) {
                _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
            }
        }
    }

    func test_send_whenTransportThrowsURLError_mapsCode() async {
        let sut = makeSUT(transport: FakeTransport([.failure(URLError(.notConnectedToInternet))]))

        await assertThrows(APIError.transport(.notConnectedToInternet)) {
            _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        transport: FakeTransport,
        token: String? = "token",
        sleeper: RecordingSleeper = RecordingSleeper()
    ) -> TMDBClient {
        TMDBClient(
            transport: transport,
            credentials: StaticCredentialProvider(token),
            retryDelay: .seconds(1),
            sleeper: sleeper
        )
    }

    private func assertStatus(_ status: Int, throws expected: APIError, line: UInt = #line) async {
        let sut = makeSUT(transport: FakeTransport([.json("{}", status: status)]))
        await assertThrows(expected, line: line) {
            _ = try await sut.send(Endpoint<Probe>(path: "/configuration"))
        }
    }
}

func assertThrows<E: Error & Equatable>(
    _ expected: E,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail("Expected \(expected) but nothing was thrown", file: file, line: line)
    } catch let error as E {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Expected \(expected) but got \(error)", file: file, line: line)
    }
}
