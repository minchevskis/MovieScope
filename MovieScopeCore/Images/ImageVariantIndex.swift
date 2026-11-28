import Foundation

/// Which sizes of each TMDB file are decoded in memory, so a new screen can
/// show one as a preview while its own size loads.
///
/// The memory cache evicts images without telling anyone, so the index drops
/// entries whose image is gone: for one file whenever it is looked up, and for
/// every file whenever the index outgrows its sweep threshold. After a sweep
/// the threshold becomes twice what survived, so sweeps stay rare and each
/// insert stays cheap on average.
struct ImageVariantIndex {
    private var variantsByFile: [String: Set<ImageRequest>] = [:]
    private let minimumSweepThreshold: Int
    private var sweepThreshold: Int

    init(sweepThreshold: Int = 256) {
        minimumSweepThreshold = sweepThreshold
        self.sweepThreshold = sweepThreshold
    }

    var fileCount: Int { variantsByFile.count }

    mutating func insert(_ request: ImageRequest, isCached: (ImageRequest) -> Bool) {
        variantsByFile[request.url.lastPathComponent, default: []].insert(request)
        guard variantsByFile.count > sweepThreshold else { return }
        for (file, variants) in variantsByFile {
            keep(variants.filter(isCached), for: file)
        }
        sweepThreshold = max(minimumSweepThreshold, variantsByFile.count * 2)
    }

    /// The variants of `path`'s file that are still cached, largest first.
    mutating func cachedVariants(forImagePath path: String, isCached: (ImageRequest) -> Bool) -> [ImageRequest] {
        let file = (path as NSString).lastPathComponent
        guard let variants = variantsByFile[file] else { return [] }
        let cached = variants.filter(isCached)
        keep(cached, for: file)
        return cached.sorted { $0.maxPixelSize > $1.maxPixelSize }
    }

    private mutating func keep(_ variants: Set<ImageRequest>, for file: String) {
        variantsByFile[file] = variants.isEmpty ? nil : variants
    }
}
