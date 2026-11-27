#!/usr/bin/env bash
#
# coverage.sh: runs the unit tests with code coverage and enforces the 80%
# minimum on the MovieScopeCore framework target.
#
# Usage: ./Scripts/coverage.sh [simulator name]   (default: first available iPhone)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT="$ROOT_DIR/build/Coverage.xcresult"
THRESHOLD="80.00"
DEVICE="${1:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone[^(]*' | sed 's/ *$//')}"

rm -rf "$RESULT"
mkdir -p "$ROOT_DIR/build"
echo "Running unit tests on '$DEVICE'…"
xcodebuild test \
  -project "$ROOT_DIR/MovieScope.xcodeproj" \
  -scheme "MovieScope Dev" \
  -testPlan UnitTests \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -resultBundlePath "$RESULT" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  -quiet

echo
xcrun xccov view --report --only-targets "$RESULT"

CORE="$(xcrun xccov view --report --only-targets "$RESULT" | awk '/MovieScopeCore.framework/ { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { sub("%", "", $i); print $i } }')"
if [[ -z "$CORE" ]]; then
  echo "Error: no coverage found for MovieScopeCore.framework" >&2
  exit 1
fi
if awk -v value="$CORE" -v min="$THRESHOLD" 'BEGIN { exit !(value + 0 < min + 0) }'; then
  echo "✘ MovieScopeCore coverage $CORE% is below $THRESHOLD%" >&2
  exit 1
fi
echo "✔ MovieScopeCore coverage $CORE% (minimum $THRESHOLD%)"
