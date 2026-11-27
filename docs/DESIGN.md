# MovieScope — Design

MovieScope is an iPhone/iPad app built on The Movie Database (TMDB) API. It was
written as a senior iOS technical assignment. This document is the single
source for what gets built and why. `docs/DECISIONS.md` (created during
setup) keeps the short decision log that later changes append to.

Legend used below: **[Req]** stated by the assignment brief · **[Fact]** verified
against official docs or tested locally · **[Call]** our decision, with the reason.

---

## 1. Intent

Show senior-level command of Swift and Apple platforms through a small,
complete app. The value is less in the three screens than in how they are
built:
- architecture and access control
- Swift 6 concurrency
- native networking with queued and concurrent requests
- testing (80%+ on the framework target)
- Xcode project hygiene: schemes, environments, linting
- handling of secrets

Every non-obvious choice is written down with its reason, here and in
`docs/DECISIONS.md`.

### Goals
- Every mandatory requirement met, visibly and verifiably.
- The brief's "Goals" are covered too: queue/concurrency, actors/Sendable,
  generics, protocol-oriented design, access control, cross-platform core,
  older-OS handling, shared schemes, env vars, UI test recording.
- A reviewer can clone, build and run the tests with no token and no extra
  tools. Adding a token makes the app live.

### Requirements traceability
This is the complete list of the brief's items, paraphrased, with where each
is met. Brief numbering: requirement 2 has only sub-item (a); there is no 2b.

| Brief item | Where |
|---|---|
| 1a Trending movies in a collection view with a custom layout | §6.1 |
| 1b Paginated through infinite scrolling | §6.1, §4.3 Pagination |
| 1c Each entity shows title, image, short description | §6.1 |
| 2 Selecting a movie opens a details screen | §6.2 |
| 2a Extended, scrollable content: ratings, votes, authors, more | §6.2 |
| 3 Search movies and series, type selected in advance, throttleable | §6.3, §4.3 Throttler |
| \* All images fetched based on view size | §6.5, §4.3 Image sizing |
| Bonus: local favorites + indicator on the entity | §6.4 |
| Bonus: offline mode (storage of choice) | Partial. Favorites and cached images work offline; the rest is deferred (§9) |
| Bonus: pre-cache via concurrent/queued download | §6.1 Prefetching, §4.3 Request limiter |
| Bonus: low-res image before the final one | §6.2 [Should] |
| Bonus: image caching mechanism | §4.3 Image pipeline |
| Bonus: `.xcframework` core for tvOS, iOS, iPadOS, macOS | §8 (visionOS added, as the Goals mention it) |
| Tech: MVVM/TCA-class architecture | §3, §4 |
| Tech: SwiftUI UI, UIKit via representable | §6.1 (UIKit), §6.2–6.6 (SwiftUI) |
| Tech: SPM for dependencies; networking native | §5 SwiftLint package; §4.3 URLSession |
| Tech: Swift 6 strict concurrency | §4.2 |
| Tech: own design, style, animations | §6.6 |
| Tech: test coverage | §7 |
| Tech: SwiftLint integrated in Xcode, with rules | §5 |
| Tech: iPad + iPhone, portrait + landscape | §6.6 |
| Tech: Prod/Dev selected via scheme and configuration | §5 |
| Tech: Git repo with commit history | §9 |
| Tech: English throughout | All |
| Goal: architecture, protocol-oriented design, access control, generics | §4.1, §4.3 (`Endpoint<T>`, `PaginatedCollection<T>`, throttler) |
| Goal: REST/JSON, native networking, queue + concurrency, actors + Sendable | §4.2, §4.3 |
| Goal: secure API keys per current practice | §3 Secrets, §5 |
| Goal: shared schemes; Xcode env vars in debug | §5 |
| Goal: cross-platform (iOS/iPadOS/tvOS/visionOS) and older-OS handling | §4.1, §6.6 |
| Goal: clean code (complexity, duplication, signatures, line length) | §5 SwiftLint limits |
| Goal: 80%+ XCTest coverage on the framework target; expectations that succeed/fail; async tests; recording and running UI tests | §7 |

### Non-goals
- Complete tvOS/macOS/visionOS apps. Only the core framework is multi-platform.
- Accounts/login, ratings submission, watchlists synced to TMDB.
- Localization beyond English.
- Commercial use (TMDB terms require a separate agreement) [Fact].

### Anti-goals (would count as failure even if it "works")
- A token in Git, in a shared scheme, or in logs.
- Tests that need network access or a token.
- Duplicate-identifier crashes, or wrong images in reused cells.
- `@unchecked Sendable` / `nonisolated(unsafe)` used to silence the compiler.
  Allowed only with a written justification, and none is expected.
- Obvious unexplained gaps in mandatory scope.

---

## 2. Constraints

- **Toolchain** [Fact]: Xcode 26.6 (Swift 6.3.3) on macOS 26.5.2. Xcode 27.2 is
  the current release but needs macOS 26.6+. The README states
  "Built and tested with Xcode 26.6; requires Xcode 26+". App Store uploads
  have required Xcode 26+ since April 2026 [Fact].
  - Keep the classic project format. Never convert to Xcode 27's `.xcproj`
    format [Fact: opens only in Xcode 27+].
  - Do not enable "treat warnings as errors": a newer compiler may add
    warnings on the reviewer's machine.
- **Installed SDKs** [Fact]: iOS, tvOS, macOS, visionOS 26.5. Simulator
  runtimes: iOS 18.6, 26.0–26.5. There are no tvOS/visionOS simulators, so
  those platforms are compile-verified only.
- **TMDB** [Fact]:
  - Bearer "API Read Access Token" auth (recommended by TMDB).
  - About 40 req/s rate limit, which may change; 429 on excess.
  - `append_to_response` takes up to 20 items.
  - Attribution is required: TMDB logo plus the Terms-of-Use notice.
  - Cached TMDB content must not be kept longer than 6 months.
  - Trending's reference does not document a `page` parameter or a maximum
    page. A live check confirmed that `page` works and that pages above 500
    are rejected.
- **Time-box**: 3 working days.

---

## 3. Approaches considered

| Topic | Options | Chosen | Why |
|---|---|---|---|
| Architecture | MVVM + DI · TCA | **MVVM + constructor DI** [Call] | Shows protocols, generics and actors directly. TCA would hide much of that behind a large dependency. No DI container library. |
| Core packaging | Framework target · local Swift package | **Framework target** [Call] | Matches the brief's "framework target". Apple's xcframework guide is built around archiving a framework target [Fact]. A Swift-package xcframework from the provided script came out with no `.swiftinterface`, so it could not be imported [Fact: tested]. |
| Trending layout | Compositional layout · handwritten `UICollectionViewLayout` subclass · SwiftUI `Layout` | **Compositional, customized** [Call] | Rotation, self-sizing and Dynamic Type come largely for free, and it is visibly custom (§6.1). A subclass costs about half a day on invalidation and self-sizing. SwiftUI `Layout` is not lazy, so it suits infinite scroll poorly. |
| Cells | UIKit cells · `UIHostingConfiguration` | **UIKit cells** [Call] | Stronger UIKit evidence (brief: "show some knowledge of UIKit"). Reuse and image cancellation are explicit code. |
| Search rate control | Throttle · debounce · both | **Throttle (leading + trailing-latest)** [Call] | The brief says "throttleable" [Req]. Substituting debounce isn't clearly compliant. Building both doubles the code and tests for no requirement gained. |
| Favorites storage | SwiftData · Core Data · JSON file + actor | **JSON file owned by an actor** [Call] | The scope is one small list. `ModelContext` isn't Sendable [Fact], so SwiftData needs an isolation design that doesn't pay off here. A JSON file is portable and fully unit-testable. |
| Disk image cache | Custom disk cache · `URLCache` | **`URLCache`** [Call] | TMDB images are served with `Cache-Control: public, max-age=31919000` [Fact: tested]. URLCache honours that natively. A custom memory layer still sits on top. |
| Secrets | xcconfig injection · + obfuscation · + Keychain BYO token · backend proxy | **Gitignored xcconfig → Info.plist, Debug env override** [Call] | An embedded token is extractable whatever is done. Obfuscation adds code without real protection. Keychain protects runtime-acquired secrets, not one baked into the build. A proxy is the real fix and is documented as such. |

---

## 4. Architecture

### 4.1 Targets

| Target | Kind | Platforms | Contents |
|---|---|---|---|
| `MovieScopeCore` | Dynamic framework | iOS 18, tvOS 18, macOS 15, visionOS 2 (no Mac Catalyst) | Domain models, DTOs + mapping, endpoints, API client, transport, credentials, image configuration and sizing, image pipeline, pagination, throttler, favorites store, request limiter. **No UIKit/SwiftUI imports.** |
| `MovieScopeCoreTests` | Unit tests | iOS Simulator | Core tests. The 80%+ coverage target applies here. |
| `MovieScope` | iOS app | iPhone + iPad, iOS 18, all orientations | SwiftUI views, view models, UIKit trending screen, navigation, composition root. |
| `MovieScopeTests` | Unit tests | iOS Simulator | View model tests with fake services. |
| `MovieScopeUITests` | UI tests | iOS Simulator | Fixture-driven flows plus one recorded flow. |

Dependency direction: App → Core only. Core has no knowledge of the app. The
public API of Core is deliberately small. Everything else is `internal`, and
only `@testable import` in tests reaches it. This is the brief's "access
control" evidence.

### 4.2 Concurrency model [Call]

- Swift 6 language mode on every target, so strict concurrency checking is on.
- **App target:** default actor isolation `MainActor` and Approachable
  Concurrency on. These are Apple's recommendations for app modules [Fact: WWDC25-268,
  SE-0466]. View models are `@MainActor @Observable`; the annotation is
  written explicitly anyway for readability.
- **Core target:** default isolation `nonisolated` (SE-0466 calls MainActor
  "the wrong default" for libraries [Fact]). The `NonisolatedNonsendingByDefault`
  upcoming feature stays off, so Core's `nonisolated async` functions never run
  implicitly on the caller's actor. Decoding and downsampling therefore stay off
  the main actor.
- Shared mutable state lives in actors:
  - `ImagePipeline`
  - `FavoritesStore`
  - `RequestLimiter`
  - `ImageConfigurationStore`
- CPU-heavy work (JSON decoding, ImageIO downsampling) runs in `nonisolated`
  functions, not on the actor's executor.
- Values crossing isolation boundaries are `Sendable` value types. `CGImage`,
  `UIImage` and `URLSession` are Sendable. `NSCache` is explicitly *not*
  Sendable [Fact: compiler], so it is only ever an actor-isolated property.
- Test-only shared state (URLProtocol stub registry) is protected by
  `Synchronization.Mutex` (iOS 18) [Fact].

### 4.3 Core components

- **Networking**
  - `HTTPTransport` protocol: `data(for: URLRequest) async throws -> (Data, HTTPURLResponse)`.
  - `URLSessionTransport` is the live implementation. `FixtureTransport` serves bundled JSON and images by request path, for UI tests.
  - `Endpoint<Response: Decodable & Sendable>` is generic: path, query items, response type.
  - `TMDBClient` implements the `TMDBService` protocol:
    - `trendingMovies(page:)`
    - `searchMovies(query:page:)` and `searchTV(query:page:)`
    - `movieDetails(id:)` and `tvDetails(id:)`, both with `append_to_response=credits,reviews`
    - `configuration()`
  - Always sends `include_adult=false` and `language=en-US`.
- **Errors**
  - `APIError` cases:
    - `missingCredentials`
    - `unauthorized`
    - `notFound`
    - `rateLimited`
    - `server(status:)`
    - `decoding`
    - `transport(URLError)`
    - `cancelled`
  - A 429 is retried once after a short delay, then surfaced.
- **Credentials**
  - `CredentialProvider` protocol. A chain tries, in order:
    1. process environment `TMDB_ACCESS_TOKEN` (Dev builds only)
    2. the Info.plist value
  - Empty means `missingCredentials`. The token never appears in logs; the
    `Authorization` header is redacted.
- **Models**
  - `MediaKind` (`movie`, `tv`).
  - `MediaID` is (kind, id): Hashable and Sendable, and the identity used
    everywhere. TMDB does not document whether movie and TV ids can collide [Fact].
  - `MediaSummary` is normalized from movie and TV DTOs.
  - `MediaDetails` holds genres, runtime/episode runtime, tagline, status,
    vote average/count, people and the top 3 reviews.
  - People: directors and writers from crew `job`/`department` [Fact]; creators
    from TV `created_by` [Fact]; top-billed cast.
  - DTOs are kept separate from domain types; the mapping is unit-tested.
- **Pagination**
  - `PaginatedCollection<Item>` is a pure value type:
    - appends a page, de-duplicating by `Item.ID` and keeping the first occurrence and the order
    - tracks `nextPage` and `canLoadMore` from `total_pages`
  - `PaginationController` (`@MainActor`, generic):
    - owns the in-flight task, so a page is never requested twice concurrently
    - exposes loading/error state, retry and reset
  - Used by both Trending and Search.
- **Throttler**
  - Generic `@MainActor` throttler with an injectable interval and `Sleeper` protocol.
  - The first value fires immediately, then at most one per interval. The
    **latest value is always delivered** at the end of a burst.
  - `cancel()` and `flush()` (fire the pending value now).
- **Request limiter**: an actor capping concurrent operations (FIFO). The image
  pipeline uses it to bound downloads. This is the "queue and concurrency" evidence.
- **Image configuration**
  - `ImageConfigurationStore` fetches `/configuration` and persists it with a timestamp.
  - It refreshes when older than 7 days [Call; TMDB gives no interval [Fact]].
  - It falls back to built-in size lists captured from the live API.
- **Image sizing**
  - `ImageSizeSelector` takes the category's size list (`poster_sizes`,
    `backdrop_sizes`, `profile_sizes`) and the target **pixel** width
    (points × display scale).
  - It picks the smallest `wNNN` that is ≥ the target, falling back to the
    largest `wNNN`. It never picks `original` (unbounded size).
- **Image pipeline** (`ImagePipeline` actor)
  - Memory cache: an `NSCache` keyed by URL + pixel size.
  - In-flight de-duplication: one task per key.
  - Disk: a dedicated `URLSession` with `URLCache` (memory 20 MB / disk 200 MB [Call]).
  - Downsampling: ImageIO `CGImageSourceCreateThumbnailAtIndex` to the target
    pixel size [Fact: available on all four platforms; WWDC18-416].
  - Bounded concurrency through `RequestLimiter`. `prefetch` and `cancelPrefetch` APIs.
  - Cancellation propagates to the download.
  - Returns `CGImage`.
- **Favorites**
  - `FavoritesStore` actor behind a `FavoritesStoring` protocol.
  - Stores a JSON file at an injected URL, written atomically.
  - Each entry is a snapshot of `MediaID`, title, poster path, year and added date, so the list renders offline.
  - A corrupt file is recovered to empty and logged.

---

## 5. Project setup

- **Build configurations**: `Dev` (debug settings, `DEBUG` flag) and `Prod`
  (release settings). Both use the same live endpoint
  `https://api.themoviedb.org/3`; there is no TMDB staging [Fact].
  - The base URL lives in code: `//` starts a comment in xcconfig files [Fact].
  - Differences between the two configurations:
    - bundle id suffix `.dev`
    - display name "MovieScope Dev"
    - log level
  - Bundle id: `io.github.minchevskis.MovieScope`.
- **xcconfig files** in `Config/`:
  - `Shared.xcconfig`, `Dev.xcconfig`, `Prod.xcconfig`. Each does
    `#include? "Secrets.xcconfig"` (optional; no warning if missing [Fact]).
  - `Secrets.xcconfig` is gitignored. `Secrets.example.xcconfig` is committed.
  - `TMDB_ACCESS_TOKEN` flows into an Info.plist key `TMDBAccessToken`.
  - The app keeps a small Info.plist for that custom key; the rest is generated.
- **Shared schemes** (committed):
  - `MovieScope Dev`: Run/Test use Dev.
  - `MovieScope Prod`: Run/Profile/Archive use Prod; Test uses Dev.
  - `MovieScopeCore`: Core build and tests; used by the xcframework script.
  - Shared schemes carry only non-secret env vars:
    - `MOVIESCOPE_LOG_LEVEL`
    - `MOVIESCOPE_FIXTURES`, present but disabled
  - The brief's "environment variables from the Xcode env when running a
    target in debug" is shown by these and by the Dev-only `TMDB_ACCESS_TOKEN`
    override (set in a local, unshared scheme).
- **Test plans**:
  - `UnitTests.xctestplan`: Core + app unit tests. Coverage is gathered for
    `MovieScopeCore` and `MovieScope` [Fact: test plans can limit coverage targets].
  - `UITests.xctestplan`: UI tests with `MOVIESCOPE_FIXTURES=1` and
    `MOVIESCOPE_RESET_STATE=1` set per configuration.
- **Fixtures**:
  - JSON responses captured from the live API with the token, plus small
    local images.
  - Bundled with the app for UI tests and excluded from Prod builds.
- **SwiftLint**:
  - Added via the `SimplyDanny/SwiftLintPlugins` package as a build tool plugin
    on Core and App [Fact: SwiftLint's recommended Xcode integration].
  - `.swiftlint.yml` adjusts limits:
    - `line_length` 120/160
    - `function_body_length`, `type_body_length`, `file_length`
    - `cyclomatic_complexity` 10
    - `function_parameter_count` 5
  - It enables opt-in rules, e.g. `force_unwrapping`,
    `implicitly_unwrapped_optional`, `sorted_imports`, `first_where`,
    `contains_over_first_not_nil`, `empty_count`, `fatal_error_message`.
  - Plus one custom rule: no `print(` in Core; use `Logger`.
  - The README notes the first-build "Trust & Enable" prompt and the CLI flags
    `-skipPackagePluginValidation -skipMacroValidation` [Fact].
- **Project file**: folder-synchronized groups (Xcode 16+ project format), so
  adding a source file needs no project-file edit.
- **Signing**: automatic. Simulator builds need no team.

---

## 6. Features

### 6.1 Trending (main screen) [Req 1a–c]
- `TrendingViewModel` (`@MainActor @Observable`) uses `PaginationController`
  over `trendingMovies(page:)`.
- **UIKit screen**: `TrendingViewController` (UICollectionView, diffable data
  source keyed by `MediaID`) wrapped in a `UIViewControllerRepresentable`.
  - Item identifiers are ids, not models [Fact: Apple recommends this].
  - Identifiers are unique per snapshot [Fact: required].
- **Custom compositional layout**:
  - Section "Featured": the first 5 items as wide backdrop cards in an
    orthogonally paging row, with fixed height.
  - Section "Trending": the remaining items in an adaptive grid. Column count
    comes from the container width (min card width ~160 pt, so 2 columns on a
    portrait iPhone and 4–6 on iPad), with self-sizing heights.
  - **No item appears in both sections**, which avoids duplicate identifiers.
- **Cell**: poster (2:3), title (2 lines), short description (overview, 3
  lines), rating badge, favorite indicator.
  - Image load task cancelled in `prepareForReuse`.
  - The represented `MediaID` is checked before assigning an image.
- **Infinite scroll**: the next page is requested when display nears the end
  (threshold ~6 items). A footer shows the spinner or an error with retry.
- **Prefetching**: `UICollectionViewDataSourcePrefetching` calls the image
  pipeline's `prefetch`/`cancelPrefetch`.
- Pull-to-refresh via `UIRefreshControl`.
- Favorite changes use `reconfigureItems` (iOS 15+) [Fact].
- Selection calls back into SwiftUI navigation.

### 6.2 Details [Req 2a]
- A single SwiftUI screen for movie and TV, driven by `MediaDetails`. Scrollable.
- One request per open: details with `append_to_response=credits,reviews` [Fact].
- **Sections**:
  - Backdrop header.
  - Poster, title, tagline, year, runtime (movie) or seasons/episodes (TV),
    genres.
  - **Rating** (vote average out of 10) and **vote count**.
  - Overview.
  - **Authors** [Call: interpretation]: "Directed by / Written by" for movies,
    "Created by" for TV.
  - Top-billed cast with profile images.
  - **Reviews**: up to 3, showing author, rating and an expandable excerpt.
    TMDB's only field literally named `author` is on reviews [Fact], so both
    readings of "authors" are covered.
  - Extra facts: status, original language; budget/revenue for movies,
    networks for TV.
- Favorite toggle in the toolbar.
- Regular width (iPad, or iPhone landscape where it fits): poster and info
  side by side.
- [Should] **Low-res first**: the hero shows the grid poster already in memory
  immediately while the larger image loads. No extra request.

### 6.3 Search [Req 3]
- SwiftUI `.searchable` with `.searchScopes`: **Movies | TV Shows**, selected
  before or while searching [Req: "selecting which one in advance"].
- Queries go through the throttler:
  - The interval is 400 ms by default and injectable [Call]; the brief asks
    for "throttleable" [Req].
  - Queries are trimmed. A minimum of 2 characters, otherwise results are
    cleared.
- Changing scope searches immediately, bypassing the throttle.
- Every new search cancels the previous task. A generation counter drops
  stale responses.
- Results paginate with the same `PaginationController`.
- Rows show a poster thumbnail, title, year, a 2-line overview and the
  favorite indicator.
- States: idle prompt, loading, results, empty, error with retry, missing
  credentials.
- Tapping a result opens the shared details screen.

### 6.4 Favorites [Bonus]
- `FavoritesModel` (`@MainActor @Observable`, injected via the environment)
  mirrors `FavoritesStore`.
- The actor owns persistence; the model owns UI state. Toggle from details or
  a cell context menu.
- The indicator shows on Trending cells, Search rows and the details toolbar.
- A Favorites tab lists saved snapshots. It works offline, and images come
  from the cache when available.

### 6.5 Images [Req *, Bonus: caching, pre-cache, low-res]
- Every remote image requests a size chosen from TMDB's configuration for its
  category and its **rendered pixel size** [Req].
- SwiftUI uses a `RemoteImage` view: it measures size, combines it with
  `displayScale`, and loads via `.task(id:)`, which cancels automatically.
- UIKit cells use the same pipeline with explicit cancellation.
- Images fade in. The placeholder is a neutral tile with an SF Symbol.

### 6.6 App shell, adaptivity, design
- `TabView` (Trending, Search, Favorites) with `.sidebarAdaptable`: a sidebar
  on iPad, a tab bar on iPhone. Each tab owns a `NavigationStack`.
- Portrait and landscape on both devices [Req]. iPad supports multitasking
  sizes.
- **Older-OS handling** [Req: Goals]: iOS 26 Liquid Glass (`glassEffect`) on
  floating controls/badges behind `#available(iOS 26, *)`, with a material
  fallback on iOS 18. Both are tested on the installed runtimes.
- **Accessibility**:
  - Dynamic Type everywhere except the fixed-height featured row, which
    truncates gracefully.
  - Combined VoiceOver labels on cells: title, rating, favorite state.
  - Reduce Motion respected.
  - `accessibilityIdentifier`s for UI tests.
- **Animations**: favorite `symbolEffect(.bounce)`, cell press scale, image
  fade.
- **About screen** (toolbar): TMDB logo and the Terms-of-Use notice
  ("This application uses TMDB and the TMDB APIs but is not endorsed,
  certified, or otherwise approved by TMDB.") [Fact: required].
- **Missing token screen** with setup instructions, instead of a crash.

---

## 7. Testing [Req]

- **Core unit tests** (target ≥ 80% line coverage, measured with
  `xcrun xccov` and reported in the README):
  - URL and endpoint building.
  - Decoding with real fixtures: trending, search movie/TV, details movie/TV,
    configuration, TMDB error bodies.
  - Status → error mapping: 401, 404, 429 with a single retry, 5xx,
    malformed JSON.
  - Credential chain, including missing and empty tokens.
  - Image size selection (edge cases: tiny, exact, larger than all).
  - Pagination de-duplication across overlapping pages, order preserved,
    end detection, no duplicate in-flight request, retry after failure.
  - Throttler: leading fire, trailing-latest, cancellation, flush. Driven by a
    controllable `Sleeper`; Swift's standard library has no test clock [Fact].
  - Image pipeline with a fake transport and local image fixtures:
    - memory hit
    - in-flight de-duplication
    - cancellation
    - output pixel size
    - concurrency cap respected
  - Favorites store in a temp directory: add/remove/persist/reload, corrupt
    file recovery.
  - `URLSessionTransport` integration through a `URLProtocol` stub
    (Mutex-protected registry).
- **XCTest techniques** [Req]:
  - Async tests use `await fulfillment(of:)`; `wait(for:)` is unavailable in
    async contexts [Fact].
  - Success expectations.
  - **Inverted expectations** (`isInverted`) for "must not happen": a stale
    result never applied, a throttled call never sent.
- **App unit tests**: view models with fake services.
  - Trending: load, paginate, error, retry, refresh.
  - Search: throttle, scope switch, cancellation, stale guard.
  - Details mapping and favorites model.
- **UI tests**: fixtures plus reset state; no network.
  - Trending loads and scrolling loads page 2.
  - Details shows its sections.
  - Search with Movies → TV scope switch.
  - A favorite toggle appears in the Favorites tab.
  - Missing-token screen.
  - **One flow is recorded with Xcode 26's UI recorder** [Fact: supported],
    then given stronger assertions. It is marked in a comment as
    recorded-then-edited, distinct from the handwritten tests.
- Every test passes on a clean checkout with **no token**.

---

## 8. XCFramework [Bonus]

- `Scripts/build-xcframework.sh`:
  - Builds the `MovieScopeCore` framework target (a Swift-package build
    produced no `.swiftinterface` [Fact: tested]).
  - Configuration is selectable (`Prod`).
  - Output named `MovieScopeCore.xcframework` in `Artifacts/` (gitignored).
  - Fails if any slice lacks `Modules/*.swiftinterface`.
  - Slices: iOS, iOS Simulator, tvOS, tvOS Simulator, macOS, visionOS,
    visionOS Simulator.
- The binary is **not** committed. It may be attached to a GitHub release.
- The Core builds for all four platforms.

---

## 9. Delivery

- Public GitHub repo `minchevskis/MovieScope`, on `main`.
- Small, meaningful commits, one step each.
- `.gitignore` covers:
  - `xcuserdata`, `DerivedData`
  - `Artifacts/`
  - `Config/Secrets.xcconfig`
  - `.DS_Store`
- `README.md`:
  - overview and screenshots (iPhone + iPad)
  - requirements (Xcode 26.6+)
  - token setup
  - schemes and environments
  - architecture diagram
  - testing and coverage numbers
  - SwiftLint notes
  - xcframework
  - decisions summary
  - known limitations and next steps
  - TMDB attribution
- `docs/DECISIONS.md`: short dated entries (decision · alternatives · reason).

### Deferred deliberately (time-box)
**Offline mode for Trending, Details and Search.** Favorites and
already-cached images work offline. Trending, details and search show an
offline error with retry. The README documents the planned design:
- persist the last trending pages and opened details as timestamped JSON snapshots
- serve them when requests fail for connectivity reasons, with a "showing saved results" banner
- purge after 30 days, well inside TMDB's 6-month cap [Fact]
- search stays online-only
