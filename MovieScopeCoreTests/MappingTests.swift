@testable import MovieScopeCore
import XCTest

/// DTO → domain mapping rules, using small inline payloads.
final class MappingTests: XCTestCase {
    func test_map_emptyReleaseDate_isNil() throws {
        let item = try FixtureLoader.decode(MediaListItemDTO.self, json: """
        {"id": 1, "title": "A", "overview": "", "release_date": "", "vote_average": 7.1, "vote_count": 10}
        """)

        XCTAssertNil(item.toSummary(kind: .movie).releaseDate)
    }

    func test_map_releaseDate_parsesDayInUTC() throws {
        let item = try FixtureLoader.decode(MediaListItemDTO.self, json: """
        {"id": 1, "title": "A", "release_date": "2024-03-01"}
        """)

        let date = try XCTUnwrap(item.toSummary(kind: .movie).releaseDate)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: date), DateComponents(year: 2024, month: 3, day: 1))
    }

    func test_map_nullPosterAndBackdrop_areNil() throws {
        let item = try FixtureLoader.decode(MediaListItemDTO.self, json: """
        {"id": 7, "title": "No Art", "poster_path": null, "backdrop_path": null}
        """)

        let summary = item.toSummary(kind: .movie)
        XCTAssertNil(summary.posterPath)
        XCTAssertNil(summary.backdropPath)
        XCTAssertEqual(summary.overview, "")
        XCTAssertEqual(summary.voteAverage, 0)
        XCTAssertEqual(summary.voteCount, 0)
    }

    func test_map_tvUsesNameAndFirstAirDate() throws {
        let item = try FixtureLoader.decode(MediaListItemDTO.self, json: """
        {"id": 9, "name": "Show", "first_air_date": "2008-01-20", "overview": "o"}
        """)

        let summary = item.toSummary(kind: .tv)
        XCTAssertEqual(summary.id, MediaID(kind: .tv, id: 9))
        XCTAssertEqual(summary.title, "Show")
        XCTAssertNotNil(summary.releaseDate)
    }

    func test_map_directorsAndDedupedWriters() throws {
        let credits = try FixtureLoader.decode(CreditsDTO.self, json: """
        {"cast": [], "crew": [
          {"id": 1, "name": "A", "job": "Director", "department": "Directing"},
          {"id": 2, "name": "B", "job": "Screenplay", "department": "Writing"},
          {"id": 2, "name": "B", "job": "Writer", "department": "Writing"},
          {"id": 3, "name": "C", "job": "Novel", "department": "Writing"},
          {"id": 4, "name": "D", "job": "Producer", "department": "Production"}
        ]}
        """)

        XCTAssertEqual(credits.directors.map(\.name), ["A"])
        XCTAssertEqual(credits.writers.map(\.name), ["B", "C"])
    }

    func test_map_castSortedByOrderAndCappedAt15() throws {
        let members = (0..<20).reversed().map { index in
            #"{"id": \#(index), "name": "P\#(index)", "character": "C", "order": \#(index)}"#
        }
        let credits = try FixtureLoader.decode(CreditsDTO.self, json: #"{"cast": [\#(members.joined(separator: ","))], "crew": []}"#)

        let cast = credits.cast(limit: 15)
        XCTAssertEqual(cast.count, 15)
        XCTAssertEqual(cast.first?.person.name, "P0")
        XCTAssertEqual(cast.last?.person.name, "P14")
    }

    func test_map_reviewsCappedAt3_ratingOptional() throws {
        let reviews = try FixtureLoader.decode(ReviewsDTO.self, json: """
        {"results": [
          {"id": "r1", "author": "Ann", "author_details": {"rating": 8.0}, "content": "Great", "created_at": "2024-01-02T03:04:05.678Z"},
          {"id": "r2", "author": "Bob", "author_details": {"rating": null}, "content": "Ok", "created_at": "2024-01-02T03:04:05Z"},
          {"id": "r3", "author": "Cy", "content": "Meh"},
          {"id": "r4", "author": "Di", "content": "Hidden"}
        ]}
        """)

        let mapped = reviews.reviews(limit: 3)
        XCTAssertEqual(mapped.map(\.author), ["Ann", "Bob", "Cy"])
        XCTAssertEqual(mapped[0].rating, 8.0)
        XCTAssertNil(mapped[1].rating)
        XCTAssertNotNil(mapped[0].createdAt)
        XCTAssertNotNil(mapped[1].createdAt)
        XCTAssertNil(mapped[2].createdAt)
    }

    func test_map_movieDetails_zeroRuntimeBudgetAndEmptyTagline_areNil() throws {
        let dto = try FixtureLoader.decode(MovieDetailsDTO.self, json: """
        {"id": 5, "title": "T", "runtime": 0, "budget": 0, "revenue": 0, "tagline": "", "genres": [{"id": 1, "name": "Drama"}]}
        """)

        let details = dto.toDetails()
        XCTAssertNil(details.runtimeMinutes)
        XCTAssertNil(details.budget)
        XCTAssertNil(details.revenue)
        XCTAssertNil(details.tagline)
        XCTAssertEqual(details.genres, ["Drama"])
        XCTAssertTrue(details.reviews.isEmpty)
    }

    func test_map_tvDetailsFixture_hasCreatorsSeasonsAndNetworks() throws {
        let details = try FixtureLoader.decode(TVDetailsDTO.self, from: "tv_details").toDetails()

        XCTAssertEqual(details.summary.id, MediaID(kind: .tv, id: 1396))
        XCTAssertEqual(details.creators.map(\.name), ["Vince Gilligan"])
        XCTAssertEqual(details.networks, ["AMC"])
        XCTAssertNotNil(details.seasonCount)
        XCTAssertEqual(details.reviews.count, 3)
        XCTAssertTrue(details.directors.isEmpty)
    }

    func test_map_castDeduplicatesPeople_joiningCharacters() throws {
        let credits = try FixtureLoader.decode(CreditsDTO.self, json: """
        {"cast": [
          {"id": 1, "name": "Peter", "character": "Mandrake", "order": 0},
          {"id": 2, "name": "George", "character": "Turgidson", "order": 1},
          {"id": 1, "name": "Peter", "character": "Muffley", "order": 2}
        ], "crew": []}
        """)

        let cast = credits.cast(limit: 15)

        XCTAssertEqual(cast.map(\.person.id), [1, 2], "Each person appears once (unique SwiftUI identity)")
        XCTAssertEqual(cast.first?.character, "Mandrake / Muffley")
    }
}
