#!/usr/bin/env bash
################################################################################
# Tests for claude/statusline.sh: project kind detection and the rendered box
#
# The icon beside the folder name comes from an ordered marker table where the
# first match wins, so the order is the whole policy and the easy thing to break.
# Each case builds a throwaway project root with only the files named and asserts
# the NAME the table picks, which reads in a diff where a glyph would not.
#
# The precedence cases are the point: a framework beats its language, TypeScript
# beats Node, a language beats both a package.json that only builds its assets
# and Docker, and a bare Makefile says nothing.
#
# The render cases draw the whole box and check that its rows line up, and that
# an empty usage field from the JSON stays empty instead of shifting into the
# field beside it.
################################################################################

STATUSLINE="$DOTFILES/claude/statusline.sh"
SL_ROOT="$(mktemp -d "$SCRATCH/statusline.XXXXXX")"

# case name, expected NAME (empty for none), then the files to create
SL_CASES=(
  "makefile-alone||Makefile"
  "empty||"
  "laravel|LARAVEL|artisan composer.json docker-compose.yml"
  "symfony|SYMFONY|symfony.lock composer.json"
  "rails|RAILS|bin/rails Gemfile"
  "django|DJANGO|manage.py requirements.txt"
  "next|NEXT|next.config.mjs tsconfig.json package.json"
  "typescript|TYPESCRIPT|tsconfig.json package.json"
  "node|NODE|package.json"
  "deno|DENO|deno.json"
  "php-in-docker|PHP|composer.json docker-compose.yml Makefile"
  "php-with-assets|PHP|composer.json package.json"
  "python-with-assets|PYTHON|pyproject.toml package.json node_modules"
  "python-uv|PYTHON|uv.lock"
  "rust|RUST|Cargo.toml"
  "go|GO|go.mod"
  "kotlin-glob|KOTLIN|Main.kt"
  "ruby|RUBY|Gemfile"
  "swift|SWIFT|Package.swift"
  "elixir|ELIXIR|mix.exs"
  "csharp-glob|CSHARP|App.csproj"
  "cpp-beats-c|CPP|main.cpp util.h"
  "c|C|main.c Makefile"
  "cmake-alone|CMAKE|CMakeLists.txt"
  "terraform|TERRAFORM|main.tf"
  "docker-alone|DOCKER|Dockerfile"
)

for c in "${SL_CASES[@]}"; do
  IFS='|' read -r name _ files <<< "$c"
  mkdir -p "$SL_ROOT/$name"
  for f in $files; do
    mkdir -p "$SL_ROOT/$name/$(dirname "$f")"
    : > "$SL_ROOT/$name/$f"
  done
done

# One bash for every case: sourcing the script is the slow part, and it renders
# nothing when sourced. Run from a bait directory whose files match the glob
# markers under other names: a glob that expanded here instead of under $dir would
# come back as Bait.kt, find no such file in the case, and miss the detection.
SL_BAIT="$(mktemp -d "$SCRATCH/statusline-bait.XXXXXX")"
: > "$SL_BAIT/Bait.kt"; : > "$SL_BAIT/Bait.csproj"; : > "$SL_BAIT/bait.tf"; : > "$SL_BAIT/bait.c"
SL_GOT="$(cd "$SL_BAIT" && bash -c '
  source "$1"; shift
  for d in "$@"; do printf "%s=%s\n" "$(basename "$d")" "$(detect_language_name "$d")"; done
' _ "$STATUSLINE" "$SL_ROOT"/*)"

for c in "${SL_CASES[@]}"; do
  IFS='|' read -r name want _ <<< "$c"
  got="$(sed -n "s/^$name=//p" <<< "$SL_GOT")"
  it "$name → ${want:-nothing}"
  assert_eq "$want" "$got"
done

it "every table entry has a name, an icon and at least one marker"
assert_eq "" "$(bash -c '
  source "$1"
  for e in "${LANG_MARKERS[@]}"; do
    IFS="|" read -r n i m <<< "$e"
    [[ -n "$n" && -n "$i" && -n "$m" ]] || printf "%s " "$e"
  done
' _ "$STATUSLINE")"

it "detect_language returns the icon of the detected entry"
assert_eq "$(bash -c 'source "$1"; for e in "${LANG_MARKERS[@]}"; do [[ $e == RUST\|* ]] && { e="${e#*|}"; printf "%s" "${e%%|*}"; }; done' _ "$STATUSLINE")" \
  "$(bash -c 'source "$1"; detect_language "$2"' _ "$STATUSLINE" "$SL_ROOT/rust")"

# ── The rendered box ─────────────────────────────────────────────────────────
# Full renders from a JSON fixture, with a throwaway $HOME so no speak console
# state leaks in, and the ANSI stripped. Widths are measured here with the rule
# the layout documents (Nerd Font private-use glyphs are one cell, East Asian
# wide two), so a padding mistake shows up as rows of different widths.

sl_render() { # dir context_percent rate_limits_json
  printf '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":%s},"rate_limits":%s}' \
    "$1" "$2" "$3" |
    env HOME="$SL_HOME" bash "$STATUSLINE" | sed $'s/\x1b\\[[0-9;]*m//g'
}

# Prints "<width>:<column of the middle divider>" for each row
sl_geometry() {
  python3 -c '
import sys, unicodedata
def w(ch):
    cp = ord(ch)
    if 0xE000 <= cp <= 0xF8FF or 0xF0000 <= cp <= 0x10FFFD: return 1
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
for line in sys.stdin.read().splitlines():
    cols, mid = 0, -1
    for i, ch in enumerate(line):
        if i > 0 and i < len(line) - 1 and ch in "┬│┴" and mid < 0: mid = cols
        cols += w(ch)
    print(f"{cols}:{mid}")
'
}

SL_HOME="$(mktemp -d "$SCRATCH/statusline-home.XXXXXX")"
SL_SHORT="$(mktemp -d "$SCRATCH/statusline-render.XXXXXX")/a"
SL_LONG="$(dirname "$SL_SHORT")/a-folder-name-long-enough-to-widen-the-left-column"
mkdir -p "$SL_SHORT" "$SL_LONG"
SL_RESET=$(( $(date +%s) + 3600 ))

for dir in "$SL_SHORT" "$SL_LONG"; do
  OUT="$(sl_render "$dir" 42 "{\"five_hour\":{\"used_percentage\":30,\"resets_at\":$SL_RESET}}")"
  it "$(basename "$dir" | cut -c1-12): the box has five rows"
  assert_eq 5 "$(grep -c . <<< "$OUT")"
  it "$(basename "$dir" | cut -c1-12): every row has the same width and the divider in the same column"
  assert_eq 1 "$(sl_geometry <<< "$OUT" | sort -u | grep -c .)"
done

OUT="$(sl_render "$SL_SHORT" 42 '{}')"
it "no rate limits at all says so instead of drawing an empty bar"
assert_contains "$OUT" "no usage data yet"

it "and the context cell beside it keeps its own value"
assert_contains "$OUT" "42%"

OUT="$(sl_render "$SL_SHORT" 7 '{"five_hour":{"used_percentage":30}}')"
it "usage with no reset time keeps the percentage in the usage cell"
assert_contains "$(sed -n 4p <<< "$OUT")" "30%"

it "and the empty reset field does not pull it into the context cell"
assert_contains "$(sed -n 3p <<< "$OUT")" "7%"

OUT="$(sl_render "$SL_SHORT" 7 "{\"five_hour\":{\"resets_at\":$SL_RESET}}")"
it "a reset time with no percentage still reads as no usage data"
assert_contains "$OUT" "no usage data yet"
