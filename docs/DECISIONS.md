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
