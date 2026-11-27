@testable import MovieScope
import MovieScopeCore
import XCTest

@MainActor
final class DetailsViewModelTests: XCTestCase {
    func test_load_success_setsLoaded() async {
        let service = FakeTMDBService()
        let details = MediaDetails(summary: .stub(1, title: "Loaded"), genres: ["Drama"])
        await service.setDetails(MediaID(kind: .movie, id: 1), .success(details))
        let sut = DetailsViewModel(id: MediaID(kind: .movie, id: 1), placeholder: nil, service: service)

        await sut.load()

        XCTAssertEqual(sut.state, .loaded(details))
        XCTAssertEqual(sut.title, "Loaded")
    }

    func test_load_failure_setsFailedMessage() async {
        let service = FakeTMDBService()
        await service.setDetails(MediaID(kind: .movie, id: 1), .failure(APIError.transport(.notConnectedToInternet)))
        let sut = DetailsViewModel(id: MediaID(kind: .movie, id: 1), placeholder: nil, service: service)

        await sut.load()

        XCTAssertEqual(sut.state, .failed("You appear to be offline. Check your connection and try again."))
    }

    func test_title_usesPlaceholderBeforeLoad() {
        let sut = DetailsViewModel(
            id: MediaID(kind: .movie, id: 1),
            placeholder: .stub(1, title: "From the grid"),
            service: FakeTMDBService()
        )

        XCTAssertEqual(sut.state, .loading)
        XCTAssertEqual(sut.title, "From the grid")
        XCTAssertEqual(sut.summary?.posterPath, "/poster1.jpg")
    }

    func test_load_tv_requestsTVDetails() async {
        let service = FakeTMDBService()
        let id = MediaID(kind: .tv, id: 1396)
        await service.setDetails(id, .success(MediaDetails(summary: .stub(1396, kind: .tv))))
        let sut = DetailsViewModel(id: id, placeholder: nil, service: service)

        await sut.load()

        let calls = await service.detailsCalls
        XCTAssertEqual(calls, [id])
    }

    func test_load_whenAlreadyLoaded_doesNotRefetch() async {
        let service = FakeTMDBService()
        let id = MediaID(kind: .movie, id: 1)
        await service.setDetails(id, .success(MediaDetails(summary: .stub(1))))
        let sut = DetailsViewModel(id: id, placeholder: nil, service: service)

        await sut.load()
        await sut.load()

        let calls = await service.detailsCalls
        XCTAssertEqual(calls.count, 1)
    }

    func test_retry_afterFailure_loadsAgain() async {
        let service = FakeTMDBService()
        let id = MediaID(kind: .movie, id: 1)
        await service.setDetails(id, .failure(APIError.server(status: 500)))
        let sut = DetailsViewModel(id: id, placeholder: nil, service: service)
        await sut.load()

        await service.setDetails(id, .success(MediaDetails(summary: .stub(1))))
        await sut.retry()

        XCTAssertEqual(sut.state, .loaded(MediaDetails(summary: .stub(1))))
    }
}

final class DetailsFormattingTests: XCTestCase {
    func test_metadata_movie_joinsYearRuntimeAndGenres() {
        let details = MediaDetails(
            summary: MediaSummary(
                id: MediaID(kind: .movie, id: 1), title: "T", overview: "", posterPath: nil, backdropPath: nil,
                voteAverage: 0, voteCount: 0, releaseDate: Date(timeIntervalSince1970: 1_704_067_200)
            ),
            genres: ["Action", "Sci-Fi"],
            runtimeMinutes: 135
        )

        XCTAssertEqual(DetailsFormatting.metadataLine(for: details), "2024 · 2h 15m · Action, Sci-Fi")
    }

    func test_metadata_tv_usesSeasonsAndEpisodes() {
        let details = MediaDetails(summary: .stub(1, kind: .tv), seasonCount: 5, episodeCount: 62)

        XCTAssertEqual(DetailsFormatting.metadataLine(for: details), "5 seasons · 62 episodes")
    }

    func test_metadata_singleSeason_isSingular() {
        let details = MediaDetails(summary: .stub(1, kind: .tv), seasonCount: 1, episodeCount: 1)

        XCTAssertEqual(DetailsFormatting.metadataLine(for: details), "1 season · 1 episode")
    }
}
