#!/bin/bash
################################################################################
# Palette Drift Checker
#
# Description:
#   Best-effort lint for the linked_data_dark_rainbow palette, synced by hand
#   across several tools (docs/COLORS.md is the source of truth). Flags the most
#   likely drift: a core color whose hex no longer matches the canonical
#   Starship palette, or a stale "total unique colors" count in COLORS.md.
#   Intentionally shallow: green means "no obvious drift", not a formal proof.
#
# Usage:
#   ./scripts/colors-check.sh   |   make colors-check
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARSHIP="$DOTFILES/starship/starship.toml"
COLORS_DOC="$DOTFILES/docs/COLORS.md"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'; RED=$'\033[38;2;255;77;77m'
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; RED=""
fi
pass() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; ISSUES=$((ISSUES+1)); }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }
ISSUES=0

# Canonical core palette (10 colors), per docs/COLORS.md.
declare -a CORE=(
  "black:#000000"  "white:#ffffff"  "red:#ff4d4d"    "orange:#ffb86c"
  "yellow:#ffec99" "green:#44f373"  "cyan:#7fffd4"   "blue:#68d5ff"
  "purple:#c6a7ff" "pink:#ff6cd4"
)

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
if [[ -f "$STARSHIP" ]]; then
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

head "🔢 Color count in COLORS.md"
if [[ -f "$COLORS_DOC" ]]; then
  if grep -qiE "Total unique colors:\**\s*28" "$COLORS_DOC"; then
    pass "COLORS.md still declares 28 unique colors"
  else
    warn "COLORS.md 'Total unique colors' is not 28. Update the count or the audit"
  fi
else
  warn "docs/COLORS.md not found"
fi

head "📋 Summary"
if [[ "$ISSUES" -eq 0 ]]; then
  printf "  %sNo obvious palette drift detected.%s\n" "$GREEN" "$RESET"
else
  printf "  %s%d potential issue(s). Review against docs/COLORS.md.%s\n" "$YELLOW" "$ISSUES" "$RESET"
fi
