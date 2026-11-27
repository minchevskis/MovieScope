import Foundation
@testable import MovieScopeCore
import XCTest

/// Loads `*.fixture.json` files from the shared `Fixtures/` folder (bundled into
/// the test target) and decodes them the same way `TMDBClient` does.
final class FixtureLoader {
    static var bundle: Bundle { Bundle(for: FixtureLoader.self) }

    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "fixture.json"),
            "Missing fixture \(name).fixture.json",
            file: file,
            line: line
        )
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try TMDBClient.makeDecoder().decode(type, from: data(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try TMDBClient.makeDecoder().decode(type, from: Data(json.utf8))
    }
}
