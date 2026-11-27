#!/usr/bin/env bash
#
# build-xcframework.sh: builds MovieScopeCore into a multi-platform XCFramework
# (one slice per platform).
#
# Adapted from a generic XCFramework build script for this project's framework target:
#   - explicit project, Prod configuration by default
#   - output named after the module
#   - all Apple platforms the core supports by default
#   - fails unless every slice ships a .swiftinterface (module stability), so
#     the result is importable by newer Swift compilers
#
# Usage:
#   ./Scripts/build-xcframework.sh [options]
#
# Options (or the equivalent environment variables):
#   -s, --scheme <name>         Framework scheme (default: MovieScopeCore)            [SCHEME]
#   -c, --configuration <name>  Build configuration (default: Prod)                   [CONFIGURATION]
#   -n, --name <name>           Output name without extension (default: scheme name)  [OUTPUT_NAME]
#   -o, --output <dir>          Output directory (default: <repo>/Artifacts)          [OUTPUT_DIR]
#   -P, --platforms <list>      Comma-separated subset of:
#                               ios,ios-simulator,tvos,tvos-simulator,macos,visionos,visionos-simulator
#                               (default: all of them)                                 [PLATFORMS]
#       --keep-derived          Keep the intermediate DerivedData folder
#   -h, --help                  Show this help
#
# Requirements: Xcode with the platforms you request installed
# (Xcode > Settings > Components). Output: Artifacts/MovieScopeCore.xcframework (gitignored).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$ROOT_DIR/MovieScope.xcodeproj"

SCHEME="${SCHEME:-MovieScopeCore}"
CONFIGURATION="${CONFIGURATION:-Prod}"
OUTPUT_NAME="${OUTPUT_NAME:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/Artifacts}"
PLATFORMS="${PLATFORMS:-ios,ios-simulator,tvos,tvos-simulator,macos,visionos,visionos-simulator}"
KEEP_DERIVED=0

usage() { sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--scheme)        SCHEME="$2"; shift 2 ;;
    -c|--configuration) CONFIGURATION="$2"; shift 2 ;;
    -n|--name)          OUTPUT_NAME="$2"; shift 2 ;;
    -o|--output)        OUTPUT_DIR="$2"; shift 2 ;;
    -P|--platforms)     PLATFORMS="$2"; shift 2 ;;
    --keep-derived)     KEEP_DERIVED=1; shift ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

OUTPUT_NAME="${OUTPUT_NAME:-$SCHEME}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
DERIVED="$OUTPUT_DIR/DerivedData"
XCFRAMEWORK_PATH="$OUTPUT_DIR/$OUTPUT_NAME.xcframework"

destination_for() {
  case "$1" in
    ios)                echo "generic/platform=iOS" ;;
    ios-simulator)      echo "generic/platform=iOS Simulator" ;;
    tvos)               echo "generic/platform=tvOS" ;;
    tvos-simulator)     echo "generic/platform=tvOS Simulator" ;;
    macos)              echo "generic/platform=macOS" ;;
    visionos)           echo "generic/platform=visionOS" ;;
    visionos-simulator) echo "generic/platform=visionOS Simulator" ;;
    *) return 1 ;;
  esac
}

IFS=',' read -r -a PLATFORM_LIST <<< "$PLATFORMS"
for platform in "${PLATFORM_LIST[@]}"; do
  destination_for "$platform" >/dev/null || { echo "Error: unknown platform '$platform'." >&2; exit 2; }
done

echo "Scheme:         $SCHEME ($CONFIGURATION)"
echo "Platforms:      ${PLATFORM_LIST[*]}"
echo "Output:         $XCFRAMEWORK_PATH"
echo

# Only remove what this script owns, never the whole output directory.
rm -rf "$XCFRAMEWORK_PATH" "$DERIVED"

for platform in "${PLATFORM_LIST[@]}"; do
  echo "▸ Building $platform"
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$(destination_for "$platform")" \
    -derivedDataPath "$DERIVED/$platform" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ONLY_ACTIVE_ARCH=NO \
    -quiet
done

ARGS=()
MISSING=()
for platform in "${PLATFORM_LIST[@]}"; do
  framework="$(find "$DERIVED/$platform" -type d -path "*/Build/Products/*" -name "$SCHEME.framework" -prune -print 2>/dev/null | head -n 1 || true)"
  if [[ -n "$framework" && -d "$framework" ]]; then
    ARGS+=(-framework "$framework")
  else
    MISSING+=("$platform")
  fi
done

# A partial XCFramework is worse than none.
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: no $SCHEME.framework built for: ${MISSING[*]}" >&2
  exit 1
fi

xcodebuild -create-xcframework "${ARGS[@]}" -output "$XCFRAMEWORK_PATH"

# Every slice must carry a module interface, or apps can't `import` it.
WITHOUT_INTERFACE=()
for slice in "$XCFRAMEWORK_PATH"/*/; do
  if ! find "$slice" -path "*$SCHEME.swiftmodule/*.swiftinterface" -print -quit | grep -q .; then
    WITHOUT_INTERFACE+=("$(basename "$slice")")
  fi
done
if [[ ${#WITHOUT_INTERFACE[@]} -gt 0 ]]; then
  echo "Error: slices without a .swiftinterface: ${WITHOUT_INTERFACE[*]}" >&2
  exit 1
fi

if [[ $KEEP_DERIVED -eq 0 ]]; then
  rm -rf "$DERIVED"
fi

echo
echo "✔ Created $XCFRAMEWORK_PATH"
