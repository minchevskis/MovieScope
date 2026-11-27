import Foundation
@testable import MovieScopeCore
import XCTest

final class URLSessionTransportTests: XCTestCase {
    func test_data_returnsBodyAndStatus() async throws {
        let host = "transport-success.test"
        StubURLProtocol.register(host: host) { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil))
            return (response, Data("hello".utf8))
        }
        defer { StubURLProtocol.unregister(host: host) }
        let sut = URLSessionTransport(session: StubURLProtocol.makeSession())

        let (data, response) = try await sut.data(for: URLRequest(url: try XCTUnwrap(URL(string: "https://\(host)/a"))))

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "hello")
        XCTAssertEqual(response.statusCode, 201)
    }

    func test_data_propagatesURLError() async throws {
        let host = "transport-failure.test"
        StubURLProtocol.register(host: host) { _ in throw URLError(.timedOut) }
        defer { StubURLProtocol.unregister(host: host) }
        let sut = URLSessionTransport(session: StubURLProtocol.makeSession())

        do {
            _ = try await sut.data(for: URLRequest(url: try XCTUnwrap(URL(string: "https://\(host)/a"))))
            XCTFail("Expected an error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
    }

    func test_imagesSession_usesDedicatedURLCacheWithCapacities() throws {
        let cache = try XCTUnwrap(URLSession.images.configuration.urlCache)

        XCTAssertEqual(cache.memoryCapacity, 20 * 1024 * 1024)
        XCTAssertEqual(cache.diskCapacity, 200 * 1024 * 1024)
        XCTAssertFalse(cache === URLCache.shared)
    }

    func test_apiSession_doesNotPersistResponses() {
        let configuration = URLSession.api.configuration

        XCTAssertNil(configuration.urlCache, "Search queries must not end up in an on-disk cache")
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }
}
