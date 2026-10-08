#!/bin/bash
################################################################################
# Palette Drift Checker
#
# Description:
#   Best-effort lint for the linked_data_dark_rainbow palette, synced by hand
#   across several tools (docs/COLORS.md is the source of truth). Flags the most
#   likely drift: a Starship color whose hex no longer matches the Core Colors
#   table in COLORS.md, or a "total unique colors" count that no longer matches
#   the hexes in its four palette tables. Exits 1 on either.
#   Intentionally shallow: green means "no obvious drift", not a formal proof.
#
#   STARSHIP and COLORS_DOC can be overridden from the environment, which is
#   how the test suite hands it a drifted copy.
#
# Usage:
#   ./scripts/colors-check.sh   |   make colors-check
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARSHIP="${STARSHIP:-$DOTFILES/starship/starship.toml}"
COLORS_DOC="${COLORS_DOC:-$DOTFILES/docs/COLORS.md}"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""
fi
pass() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; ISSUES=$((ISSUES+1)); }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }
ISSUES=0

# The canonical core palette as "name:#hex", read from the Core Colors table in
# COLORS.md rather than kept here, so a colour changed in the doc is drift too.
CORE=()
if [[ -f "$COLORS_DOC" ]]; then
  while IFS= read -r pair; do CORE+=("$pair"); done < <(
    awk '/^### /{f = /^### Core Colors/} f && /^\| \*\*/' "$COLORS_DOC" |
      sed -E 's/^\| \*\*([A-Za-z]+)\*\* *\| *`(#[0-9A-Fa-f]{6})`.*/\1:\2/' | tr '[:upper:]' '[:lower:]')
fi

# Look up the canonical hex for a palette color name.
core_hex() {
  local n="$1" pair
  for pair in "${CORE[@]}"; do
    [[ "${pair%%:*}" == "$n" ]] && { echo "${pair#*:}"; return; }
  done
}

# Verify every color Starship defines matches its canonical value. Starship
# intentionally omits some core colors (e.g. pink), so we check the colors it
# *does* declare rather than requiring all ten.
head "🎨 Starship palette vs canon ($([[ -f "$STARSHIP" ]] && echo found || echo MISSING))"
# An unreadable table would leave every Starship colour untracked, and the check
# would pass having compared nothing.
if ((${#CORE[@]} == 0)); then
  warn "no Core Colors table found in COLORS.md, nothing to compare against"
elif [[ -f "$STARSHIP" ]]; then
  while IFS= read -r line; do
    name="$(echo "$line" | sed -E 's/^([a-z_]+) *=.*/\1/')"
    hex="$(echo "$line" | sed -E 's/.*"(#[0-9a-fA-F]{6})".*/\1/' | tr 'A-F' 'a-f')"
    canon="$(core_hex "$name")"
    [[ -z "$canon" ]] && continue   # not a core color we track
    if [[ "$hex" == "$canon" ]]; then
      pass "$name $hex"
    else
      warn "$name = $hex in starship.toml but canon is $canon (drift)"
    fi
  done < <(awk '/\[palettes.linked_data_dark_rainbow\]/{f=1;next} /^\[/{f=0} f' "$STARSHIP")
else
  # Without this the whole comparison is skipped in silence and the summary below
  # still reports no drift, which is the one answer this script must never give
  # when it has checked nothing.
  warn "starship.toml not found, the palette could not be checked"
fi

# The declared total against the distinct hexes in the four palette tables, so
# neither side is a number written here.
head "🔢 Color count in COLORS.md"
if [[ -f "$COLORS_DOC" ]]; then
  declared="$(grep -oiE 'Total unique colors:\**[[:space:]]*[0-9]+' "$COLORS_DOC" | grep -oE '[0-9]+$')"
  counted="$(awk '/^### /{f = /^### (Core|Extended|UI|Terminal Bright)/} f && /^\| \*\*/' "$COLORS_DOC" |
    grep -oE '`#[0-9A-Fa-f]{6}`' | tr 'a-f' 'A-F' | sort -u | grep -c .)"
  if [[ -n "$declared" && "$declared" == "$counted" ]]; then
    pass "COLORS.md declares $declared unique colors and its tables hold $counted"
  else
    warn "COLORS.md declares ${declared:-no} unique colors but its tables hold $counted"
  fi
else
  warn "docs/COLORS.md not found"
fi

head "📋 Summary"
if [[ "$ISSUES" -eq 0 ]]; then
  printf "  %sNo obvious palette drift detected.%s\n" "$GREEN" "$RESET"
else
  printf "  %s%d potential issue(s). Review against docs/COLORS.md.%s\n" "$YELLOW" "$ISSUES" "$RESET"
  exit 1
fi
