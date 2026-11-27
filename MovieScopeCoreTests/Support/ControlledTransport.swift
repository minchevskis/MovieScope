import Foundation
@testable import MovieScopeCore
import XCTest

/// A transport whose responses the test releases explicitly. Records requests
/// and which of them were cancelled while in flight.
actor ControlledTransport: HTTPTransport {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<(Data, HTTPURLResponse), any Error>
    }

    private(set) var requestedURLs: [URL] = []
    private(set) var cancelledURLs: [URL] = []
    private var waiters: [URL: [Waiter]] = [:]

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url ?? URL(fileURLWithPath: "/")
        requestedURLs.append(url)
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, HTTPURLResponse), any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters[url, default: []].append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(url: url, id: id) }
        }
    }

    func respond(to url: URL, status: Int = 200, body: Data) {
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        waiters.removeValue(forKey: url)?.forEach { $0.continuation.resume(returning: (body, response)) }
    }

    func waitForRequests(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await waitUntil(file: file, line: line) { requestedURLs.count >= count }
    }

    func waitForCancellations(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
        await waitUntil(file: file, line: line) { cancelledURLs.count >= count }
    }

    private func waitUntil(file: StaticString, line: UInt, _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Condition not met within 2 s", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }

    private func cancel(url: URL, id: UUID) {
        guard var list = waiters[url], let index = list.firstIndex(where: { $0.id == id }) else { return }
        let waiter = list.remove(at: index)
        waiters[url] = list.isEmpty ? nil : list
        cancelledURLs.append(url)
        waiter.continuation.resume(throwing: CancellationError())
    }
}

/// A minimal `TMDBService` for components that only need image configuration.
actor StubConfigurationService: TMDBService {
    private var results: [Result<ImageConfiguration, any Error>]
    private(set) var configurationCalls = 0

    init(_ results: [Result<ImageConfiguration, any Error>]) {
        self.results = results
    }

    func imageConfiguration() async throws -> ImageConfiguration {
        configurationCalls += 1
        await Task.yield()
        return try (results.isEmpty ? .failure(APIError.notFound) : results.removeFirst()).get()
    }

    func trendingMovies(page: Int) async throws -> Page<MediaSummary> { throw APIError.notFound }
    func search(_ kind: MediaKind, query: String, page: Int) async throws -> Page<MediaSummary> { throw APIError.notFound }
    func details(for id: MediaID) async throws -> MediaDetails { throw APIError.notFound }
}
