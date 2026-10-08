#!/usr/bin/env bash
################################################################################
# Tests for scripts/colors-check.sh
#
# The checker compares two copies of the palette, so each case hands it a
# drifted copy of one side and expects exit 1. The real repo has to pass, or
# `make colors-check` would already be failing on main.
################################################################################

COLORS_CHECK="$DOTFILES/scripts/colors-check.sh"

colors_run() { # starship doc
  OUT="$(env STARSHIP="$1" COLORS_DOC="$2" bash "$COLORS_CHECK" 2>&1)"
  RC=$?
}

colors_run "$DOTFILES/starship/starship.toml" "$DOTFILES/docs/COLORS.md"
it "the repo's own palette passes"
assert_eq 0 "$RC"

it "it compares every colour Starship declares, read from the doc's table"
assert_eq 9 "$(grep -c '✓ [a-z]* #' <<<"$OUT")"

CC_DIR="$(mktemp -d "$SCRATCH/colors.XXXXXX")"

sed 's/"#ff4d4d"/"#ff0000"/I' "$DOTFILES/starship/starship.toml" >"$CC_DIR/starship.toml"
colors_run "$CC_DIR/starship.toml" "$DOTFILES/docs/COLORS.md"
it "a Starship colour that drifted from the doc exits 1"
assert_eq 1 "$RC"

it "and names the colour"
assert_contains "$OUT" "red = #ff0000"

sed -E 's/(Total unique colors:\*\*) 28/\1 29/' "$DOTFILES/docs/COLORS.md" >"$CC_DIR/count.md"
colors_run "$DOTFILES/starship/starship.toml" "$CC_DIR/count.md"
it "a declared total that no longer matches the tables exits 1"
assert_eq 1 "$RC"

sed 's/^### Core Colors.*/### Renamed/' "$DOTFILES/docs/COLORS.md" >"$CC_DIR/nocore.md"
colors_run "$DOTFILES/starship/starship.toml" "$CC_DIR/nocore.md"
it "a doc whose core table cannot be read exits 1 rather than comparing nothing"
assert_eq 1 "$RC"
