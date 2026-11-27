import Foundation

/// The single seam between the app and the network. `URLSessionTransport` is the
/// live implementation; tests and UI-test fixture mode provide their own.
public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
