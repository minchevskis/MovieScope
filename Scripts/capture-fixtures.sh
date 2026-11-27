#!/bin/bash
#
# capture-fixtures.sh: refresh the JSON fixtures in Fixtures/ from the live TMDB API.
#
# Reads TMDB_ACCESS_TOKEN from Config/Secrets.xcconfig (never printed), fetches
# the endpoints the app uses, trims them to a small deterministic size and writes
# Fixtures/*.fixture.json. Unit tests and UI-test fixture mode read these files,
# so tests never touch the network.
#
# Usage: ./Scripts/capture-fixtures.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS="$ROOT/Config/Secrets.xcconfig"
OUT="$ROOT/Fixtures"
API="https://api.themoviedb.org/3"

TOKEN="$(sed -n 's/^[[:space:]]*TMDB_ACCESS_TOKEN[[:space:]]*=[[:space:]]*//p' "$SECRETS" 2>/dev/null | tail -1 | tr -d '[:space:]')"
if [[ -z "$TOKEN" ]]; then
  echo "Error: no TMDB_ACCESS_TOKEN in Config/Secrets.xcconfig" >&2
  exit 1
fi

RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT

fetch() { # <path> <query> <output>
  local status
  status="$(curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" \
    -o "$RAW/$3" -w "%{http_code}" "$API$1?$2&language=en-US")"
  echo "HTTP $status  $1"
  [[ "$status" == "200" ]] || { echo "Error: request failed" >&2; exit 1; }
}

fetch /trending/movie/week "page=1" trending1.json
fetch /trending/movie/week "page=2" trending2.json
fetch /search/movie "query=batman&page=1&include_adult=false" search_movie.json
fetch /search/tv "query=breaking&page=1&include_adult=false" search_tv.json
fetch /configuration "" configuration.json

first_id() { /usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["results"][0]["id"])' "$RAW/$1"; }
fetch "/movie/$(first_id trending1.json)" "append_to_response=credits,reviews" movie_details.json
fetch "/tv/$(first_id search_tv.json)" "append_to_response=credits,reviews" tv_details.json

/usr/bin/python3 -I - "$RAW" "$OUT" <<'PY'
import json, os, sys
raw, out = sys.argv[1], sys.argv[2]

def load(name):
    with open(os.path.join(raw, name)) as f:
        return json.load(f)

def save(name, data):
    with open(os.path.join(out, name + ".fixture.json"), "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.write("\n")

def page(name, number, total_pages, limit=8):
    data = load(name)
    data["results"] = data["results"][:limit]
    data["page"], data["total_pages"] = number, total_pages
    data["total_results"] = len(data["results"]) * total_pages
    return data

def details(name):
    data = load(name)
    credits = data.get("credits", {})
    credits["cast"] = credits.get("cast", [])[:20]
    crew = credits.get("crew", [])
    key = [c for c in crew if c.get("department") in ("Directing", "Writing")]
    other = [c for c in crew if c.get("department") not in ("Directing", "Writing")][:5]
    credits["crew"] = key + other
    data["credits"] = credits
    reviews = data.get("reviews", {"results": []})
    reviews["results"] = reviews.get("results", [])[:5]
    for review in reviews["results"]:
        review["content"] = review.get("content", "")[:1200]
    data["reviews"] = reviews
    return data

save("trending_movie_week_p1", page("trending1.json", 1, 2))
save("trending_movie_week_p2", page("trending2.json", 2, 2))
save("search_movie", page("search_movie.json", 1, 1))
save("search_tv", page("search_tv.json", 1, 1))
save("movie_details", details("movie_details.json"))
save("tv_details", details("tv_details.json"))
save("configuration", load("configuration.json"))
print("Wrote fixtures to", out)
PY
