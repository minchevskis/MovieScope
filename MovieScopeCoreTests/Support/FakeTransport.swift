import Foundation
@testable import MovieScopeCore

/// Records every request and replays queued replies in order.
actor FakeTransport: HTTPTransport {
    enum Reply: Sendable {
        case response(status: Int, body: Data)
        case failure(any Error)

        static func json(_ body: String, status: Int = 200) -> Reply {
            .response(status: status, body: Data(body.utf8))
        }
    }

    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply] = []) {
        self.replies = replies
    }

    func enqueue(_ reply: Reply) {
        replies.append(reply)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.resourceUnavailable) }
        switch replies.removeFirst() {
        case let .response(status, body):
            let url = request.url ?? URL(fileURLWithPath: "/")
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        case let .failure(error):
            throw error
        }
    }
}

/// A sleeper that returns immediately and remembers what it was asked to wait for.
actor RecordingSleeper: Sleeper {
    private(set) var durations: [Duration] = []

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
    }
}
