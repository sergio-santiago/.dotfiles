#!/usr/bin/env bash
################################################################################
# Tests for claude/statusline.sh: project kind detection
#
# The icon beside the folder name comes from an ordered marker table where the
# first match wins, so the order is the whole policy and the easy thing to break.
# Each case builds a throwaway project root with only the files named and asserts
# the NAME the table picks, which reads in a diff where a glyph would not.
#
# The precedence cases are the point: a framework beats its language, TypeScript
# beats Node, a language beats both a package.json that only builds its assets
# and Docker, and a bare Makefile says nothing.
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
