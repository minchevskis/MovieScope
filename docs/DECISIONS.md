# Decisions

Short, dated records of decisions that shape the project. Format:
**Decision** · **Alternatives** · **Reason**. Newest entries at the bottom.
The full context is in `DESIGN.md`.

## 2026-11-27: MVVM with constructor injection
- **Decision:** MVVM. `@MainActor @Observable` view models depend on protocols
  from `MovieScopeCore`. Initializers inject them, and one composition root
  builds them.
- **Alternatives:** The Composable Architecture (TCA); a DI container library.
- **Reason:** It keeps protocol-oriented design, generics, actors and access
  control visible in our own code. It avoids a large dependency. The brief
  allows either.

## 2026-11-27: Core as a framework target
- **Decision:** `MovieScopeCore` is a dynamic framework target building for
  iOS 18, tvOS 18, macOS 15 and visionOS 2, with no UI imports.
- **Alternatives:** A local Swift package.
- **Reason:** The brief measures coverage on "the framework target". Apple's
  xcframework workflow archives a framework target. A test build of a
  Swift-package xcframework had no `.swiftinterface`, so apps couldn't import it.

## 2026-11-27: iOS / iPadOS 18 minimum
- **Decision:** Deployment target iOS 18.0.
- **Alternatives:** iOS 17.
- **Reason:** The oldest simulator runtime installed is iOS 18.6, so the
  minimum is actually testable. iOS 18 also brings `Synchronization.Mutex`.
  Older-OS handling is still shown through iOS 26 Liquid Glass with an
  iOS 18 fallback.

## 2026-11-27: Concurrency defaults per module
- **Decision:**
  - App target: default actor isolation `MainActor`, Approachable Concurrency on.
  - Core and test targets: `nonisolated`, Approachable Concurrency off.
- **Alternatives:** One setting for all targets.
- **Reason:** SE-0466 and WWDC25 recommend main-actor-by-default for app
  modules and `nonisolated` for libraries. With `NonisolatedNonsendingByDefault`
  off in Core, its async APIs never run on the caller's actor implicitly, so
  decoding and downsampling stay off the main thread.

## 2026-11-27: Customized compositional layout and UIKit cells for Trending
- **Decision:** `UICollectionViewCompositionalLayout` with a featured
  orthogonal section and an adaptive self-sizing grid. UIKit cells. Wrapped
  in `UIViewControllerRepresentable`.
- **Alternatives:** A handwritten `UICollectionViewLayout` subclass; SwiftUI
  `Layout`; `UIHostingConfiguration` cells.
- **Reason:** Rotation, self-sizing and Dynamic Type come largely for free. A
  subclass costs about half a day of invalidation work. SwiftUI `Layout` isn't
  lazy. UIKit cells make reuse and image cancellation explicit.

## 2026-11-27: Throttled search (leading + trailing-latest)
- **Decision:** A configurable throttler. The first query fires immediately,
  then at most one per interval (400 ms), always ending with the latest query.
  Previous searches are cancelled and stale responses dropped.
- **Alternatives:** Debounce; both.
- **Reason:** The brief asks for "throttleable" search. Substituting debounce
  isn't clearly compliant. Building both doubles code and tests without
  meeting any extra requirement.

## 2026-11-27: Favorites in a JSON file owned by an actor
- **Decision:** `FavoritesStore` actor writing one JSON file atomically.
- **Alternatives:** SwiftData; Core Data.
- **Reason:** The data is one small list. `ModelContext` isn't `Sendable`, so
  SwiftData would need an isolation design that doesn't pay off here. A file
  is portable and fully unit-testable.

## 2026-11-27: URLCache as the image disk cache
- **Decision:** A dedicated `URLSession` with `URLCache` (20 MB memory /
  200 MB disk), plus an actor-owned in-memory cache of decoded,
  downsampled images.
- **Alternatives:** A custom disk cache.
- **Reason:** TMDB's image CDN sends `Cache-Control: public, max-age=31919000`.
  URLCache honours that natively.

## 2026-11-27: Secrets via a gitignored xcconfig
- **Decision:** `Config/Secrets.xcconfig` (gitignored, optional include) →
  Info.plist `TMDBAccessToken`. Dev builds can override it with the
  `TMDB_ACCESS_TOKEN` environment variable. The Authorization header is
  redacted in logs.
- **Alternatives:** Obfuscation; a Keychain-entered token; a backend proxy.
- **Reason:** Any token embedded in an app binary can be extracted.
  Obfuscation adds code without real protection. Keychain protects secrets
  obtained at runtime, not one baked into the build. A proxy is the real
  fix and is documented as the production path.

## 2026-11-27: Toolchain baseline
- **Decision:** Built and tested with Xcode 26.6 (Swift 6.3). Classic project
  format. Warnings are never treated as errors.
- **Alternatives:** Xcode 27.2.
- **Reason:** Xcode 27 needs macOS 26.6+. Projects in Xcode 27.2's new
  `.xcproj` format only open in Xcode 27+. App Store uploads have required
  Xcode 26+ since April 2026.

## 2026-11-27: Hand-authored project file with folder-synchronized groups
- **Decision:** `MovieScope.xcodeproj` is hand-written in the Xcode 16+ format
  (objectVersion 77). Each target maps to a folder that Xcode keeps in sync.
  Xcode's own re-save is committed as-is.
- **Alternatives:** XcodeGen or Tuist; creating the project in the Xcode UI.
- **Reason:** Adding a source file needs no project-file edit, and the
  repository needs no generator tool. A re-save by Xcode 26.6 only reformatted
  the file; the parsed contents are identical.

## 2026-11-27: Fixtures captured from the live API
- **Decision:** `Scripts/capture-fixtures.sh` captures trimmed TMDB responses
  into `Fixtures/`. Unit tests decode them. UI tests run the app on them through
  `FixtureTransport`, with artwork generated in code.
- **Alternatives:** Hand-written JSON; UI tests against the live API.
- **Reason:** Decoding is checked against real payloads. UI tests are
  deterministic and need no network or token.

## 2026-11-27: One error normaliser
- **Decision:** `APIError.init(_:)` maps any thrown error (URL errors,
  cancellation, unknown errors) to `APIError`. The client and the pagination
  controller both use it. Cancellation never surfaces as a user-facing error.
- **Alternatives:** Mapping errors separately in each layer.
- **Reason:** Error states and messages behave the same everywhere.

## 2026-11-27: Search field placement on iPad
- **Decision:** In regular width, the search field and its Movies/TV scope are
  pinned under the navigation bar, and the Search tab presents search on
  appear. iPhone keeps the system bottom field (iOS 26).
- **Alternatives:** The iPadOS 26 default (search collapsed into a toolbar button).
- **Reason:** The brief asks for the kind to be chosen in advance. The scope
  should be visible as soon as the Search tab opens.

## 2026-11-27: Layout at accessibility text sizes
- **Decision:** At accessibility content sizes, the Trending grid uses a
  300 pt minimum card width (one column on iPhone), section headers wrap, and
  the details header stacks the poster above the title. Prefetching follows the
  same widths.
- **Alternatives:** Letting text truncate.
- **Reason:** Found by a UI test rendering the screens at AX-XXXL.

## 2026-11-27: Low-resolution preview from the memory cache
- **Decision:** The details poster and backdrop first show any variant of the
  same TMDB file already decoded in memory (for example the grid poster), then
  cross-fade to the full size.
- **Alternatives:** Requesting a tiny size first (an extra request per image).
- **Reason:** An instant preview with no extra network traffic.

## 2026-11-27: Recorded UI test
- **Decision:** A flow recorded with Xcode 26's UI recorder is committed raw
  first, then hardened in a second commit: identifier queries, incidental
  gestures removed, iOS 18-compatible navigation, assertions after each step.
- **Alternatives:** Keeping the raw recording; writing the flow by hand.
- **Reason:** Shows the recorder in use, and the history makes the
  recorded-versus-edited difference visible, while the test stays stable
  across iOS 18, iOS 26 and iPad.

## 2026-11-27: Fixes from the whole-project review
- **Decision:** An independent review found no critical issues. These were
  fixed, each with a test that failed first:
  - a failed pull-to-refresh retries as a refresh
  - Search shows next-page errors with a retry
  - stale-search tests prove the generation guard, not only cancellation
  - images cover their views
  - cast is de-duplicated per person
  - API responses get an ephemeral, cache-less session
  - `/configuration` backs off after a failure
  - a trailing space doesn't re-run a search
  - the reused-cell image protection is unit-tested
  - the Trending footer re-measures when it changes
  - Dev request logging with header redaction is real
- **Alternatives:** Shipping as reviewed.
- **Reason:** The fixes were small and contained, and each was a case a
  user or reviewer could plausibly hit. The minor items it also found were
  fixed the next day (below).

## 2026-11-28: The review's minor items
- **Decision:** The seven minor findings were fixed too, each with a test
  that failed first where the behaviour is observable:
  - a cancelled image download that finishes late no longer orphans a newer
    prefetch of the same image (it could no longer be cancelled)
  - a refresh that returns the same titles with new content updates the
    cards (identifiers alone don't tell the diffable data source)
  - tab view models are built once in the composition root, and a details
    view model when a title is tapped, instead of in view initializers that
    SwiftUI re-runs on every redraw
  - tests for an empty TV air date and missing profile photos; the featured
    card shows a placeholder symbol like the grid card
  - Reduce Motion: pressed cards dim instead of shrinking, the heart doesn't
    bounce, reviews expand without animation; cross-fades stay
  - `Endpoint`, `TMDBClient.send`, `PlaceholderImageFactory` and the
    `URLSession` presets are internal; the app uses
    `URLSessionTransport.api` and `.images`
  - favorites: the store saves the wanted state instead of flipping it, and a
    failed save puts back only its own title, and only if no newer tap on it
    is pending; re-adding from a details screen that hasn't loaded keeps the year
- **Alternatives:** Leaving them as documented minor issues.
- **Reason:** Each was cheap to fix and test, and two (the favorites cases)
  could leave the screen disagreeing with what is saved.
- **Calls made:**
  - `FixtureTransport` stays public: the app's fixture mode (UI tests, demos)
    needs it.
  - Favorites store only the year, so the placeholder summary built from a
    favorite carries 1 January of that year (UTC). Only the year is ever
    shown, and the year survives a remove and re-add.
  - The view-model change is structural (no allocation left in any view
    initializer), so it has no test that failed first; the tab and details
    flows are covered by the existing UI tests.


## 2026-11-28: Search is a plain tab
- **Decision:** The Search tab no longer uses `role: .search`.
- **Alternatives:** Keeping the role and drawing a custom Movies / TV Shows
  picker; re-creating the search field every time it opens.
- **Reason:** On iOS 26 a search-role tab merges its field into the tab bar,
  and the scope bar then appears only the first time search opens. This was
  seen on a device and reproduced on the iOS 26.5 simulator. Removing
  `isPresented` or changing the scope activation didn't help; removing the role
  alone did. The brief needs the kind chosen in advance, so the scopes must
  always be there. As a plain tab, Search opens straight into the field with
  the scopes under it. `test_search_scopesAppearEveryTimeSearchOpens` failed
  before the change. iPhone no longer uses the bottom field mentioned in the
  iPad entry above.

## 2026-11-28: Image loading soft spots
- **Decision:** Three weaknesses found in a further self-review were fixed,
  each with a test that failed first:
  - Images on screen no longer wait behind prefetches. A `RequestQueue` with
    a high and a low lane replaces the first-come-first-served
    `RequestLimiter` actor, and a queued prefetch that comes on screen is
    promoted. The queue is a plain value inside the `ImagePipeline` actor, so
    a promotion can't race the download it moves. Downloads wait for a slot
    on a continuation the pipeline resumes.
  - Prefetch and cancel requests from the collection view are applied in the
    order they were made. Each starts with an async configuration lookup, so
    a cancel could overtake its prefetch and leave that download running.
  - The index of decoded sizes per file drops entries the memory cache has
    evicted: on lookup, and in a sweep whenever it outgrows a threshold that
    becomes twice what survived.
- **Alternatives:** Adding a promotion message to the `RequestLimiter` actor
  (it could arrive before the download it promotes); reserving slots for
  on-screen images (a visible image that joins a queued prefetch would still
  wait); an `NSCacheDelegate` for evictions (called on arbitrary threads,
  outside the actor).
- **Reason:** Each had a real cost: a slower image on screen during fast
  scrolling, a wasted download, and an index that grew for as long as the app
  ran.
- **Calls made:** `RequestLimiter` and its tests were removed instead of being
  left unused. Its guarantees (the cap, a cancelled waiter never starts, a
  failure frees its slot) are now `ImagePipeline` tests.

## 2026-11-28: Featured cards show a description; offline mode is the one open item
- **Decision:** The five featured cards now show a one-line overview under
  the title, like the grid cards' three-line one, so every Trending entity
  has a title, an image and a short description (brief point 1c). Offline mode
  stays the single unfinished feature. Apps for tvOS and visionOS, and a
  backend proxy for the token, are recorded as scope decisions rather than
  unfinished work.
- **Alternatives:** Leaving the featured cards as they were; building tvOS or
  visionOS apps; adding a proxy server.
- **Reason:** 1c is a required point, and its gap was an oversight found while
  checking every point of the brief. The brief's own bonus asks for a core
  framework "to be consumed" by other platforms, which is delivered; full apps
  for them would be new scope two days before the deadline. A proxy needs a
  server a reviewer couldn't run. Image cache retention moves into the offline
  mode design, since both follow TMDB's 6-month caching limit.
