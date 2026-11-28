import Foundation
@testable import MovieScopeCore
import XCTest

final class ImageVariantIndexTests: XCTestCase {
    func test_lookup_returnsCachedVariantsLargestFirst() {
        var sut = ImageVariantIndex()
        sut.insert(variant("poster.jpg", 100)) { _ in true }
        sut.insert(variant("poster.jpg", 300)) { _ in true }

        let variants = sut.cachedVariants(forImagePath: "/poster.jpg") { _ in true }

        XCTAssertEqual(variants.map(\.maxPixelSize), [300, 100])
    }

    func test_lookup_forgetsVariantsTheCacheEvicted() {
        var sut = ImageVariantIndex()
        let small = variant("poster.jpg", 100)
        sut.insert(small) { _ in true }
        sut.insert(variant("poster.jpg", 300)) { _ in true }

        _ = sut.cachedVariants(forImagePath: "/poster.jpg") { $0 != small }
        let later = sut.cachedVariants(forImagePath: "/poster.jpg") { _ in true }

        XCTAssertEqual(later.map(\.maxPixelSize), [300], "An evicted variant stays forgotten")
    }

    func test_lookup_forgetsFileWhenNothingIsCached() {
        var sut = ImageVariantIndex()
        sut.insert(variant("poster.jpg", 100)) { _ in true }

        let variants = sut.cachedVariants(forImagePath: "/poster.jpg") { _ in false }

        XCTAssertTrue(variants.isEmpty)
        XCTAssertEqual(sut.fileCount, 0)
    }

    func test_insert_sweepsEvictedFilesOnceTheIndexOutgrowsItsThreshold() {
        var sut = ImageVariantIndex(sweepThreshold: 2)
        var cached: Set<ImageRequest> = []
        for file in ["a.jpg", "b.jpg"] {
            let request = variant(file, 100)
            cached.insert(request)
            sut.insert(request) { cached.contains($0) }
        }
        cached.removeAll() // The memory cache evicts both.

        let fresh = variant("c.jpg", 100)
        cached.insert(fresh)
        sut.insert(fresh) { cached.contains($0) }

        XCTAssertEqual(sut.fileCount, 1, "Files whose images are all gone are dropped")
    }

    func test_insert_waitsLongerBeforeTheNextSweepWhenEverythingIsStillCached() {
        var sut = ImageVariantIndex(sweepThreshold: 2)
        for file in ["a.jpg", "b.jpg", "c.jpg"] {
            sut.insert(variant(file, 100)) { _ in true }
        }

        var checks = 0
        sut.insert(variant("d.jpg", 100)) { _ in
            checks += 1
            return true
        }

        XCTAssertEqual(sut.fileCount, 4)
        XCTAssertEqual(checks, 0, "Sweeping on every insert would make each insert scan the whole index")
    }

    private func variant(_ file: String, _ size: Int) -> ImageRequest {
        ImageRequest(url: URL(fileURLWithPath: "/t/p/w\(size)/\(file)"), maxPixelSize: size)
    }
}
