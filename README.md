# MovieScope

An iPhone and iPad app for browsing trending movies, searching movies and TV
shows, and keeping local favorites. Built on [The Movie Database (TMDB)](https://www.themoviedb.org) API.

> Work in progress. The full README (architecture, testing, coverage,
> decisions) is completed at the end of the build. See `docs/DESIGN.md`.

## Requirements

- Xcode 26.6 or later (built and tested with Xcode 26.6, Swift 6.3)
- iOS / iPadOS 18.0 or later

## Setup

1. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (gitignored).
2. Paste your TMDB **API Read Access Token** (themoviedb.org → Settings → API) as
   the value of `TMDB_ACCESS_TOKEN`.
3. Open `MovieScope.xcodeproj` and run the **MovieScope Dev** scheme.

Without a token the project still builds and every test passes. The app then
shows setup instructions instead of content.

On the first build Xcode asks you to **Trust & Enable** the SwiftLint build tool
plugin. Command-line builds need `-skipPackagePluginValidation -skipMacroValidation`.

---

This product uses the TMDB API but is not endorsed or certified by TMDB.
