#!/usr/bin/env bash
################################################################################
# Test runner
#
# Description:
#   Runs every scripts/tests/test-*.sh file and reports one summary. Plain bash,
#   no framework and no extra formula to install, matching the rest of the repo.
#
#   Each test file sources this runner's helpers, so it gets `it`, `assert_eq`,
#   `assert_contains` and a scratch directory that is removed on exit. Tests never
#   touch the real Homebrew: they run against a fake `brew` on a temporary PATH.
#
# Usage:
#   ./scripts/tests/run.sh   |   make test
#   ./scripts/tests/run.sh test-brew-maintenance.sh   (one file)
################################################################################

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$TESTS_DIR/../.." && pwd)"
export DOTFILES

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; RED=$'\033[38;2;255;77;77m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; RED=""
fi

# ── Assertions ──────────────────────────────────────────────────────────────
# Counters live in the runner's shell. Test files are sourced rather than
# executed so a failure inside one is visible to the summary here.
T_PASS=0; T_FAIL=0; CURRENT=""

it() { CURRENT="$1"; }

_ok()   { T_PASS=$((T_PASS + 1)); printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$CURRENT"; }
_bad()  { T_FAIL=$((T_FAIL + 1)); printf "  %s✗%s %s\n" "$RED" "$RESET" "$CURRENT"
          printf "      %s%s%s\n" "$DIM" "$1" "$RESET"; }

assert_eq() { # expected actual
  if [[ "$1" == "$2" ]]; then _ok; else _bad "expected '$1', got '$2'"; fi
}

assert_contains() { # haystack needle
  if [[ "$1" == *"$2"* ]]; then _ok; else _bad "expected output to contain '$2'"; fi
}

assert_not_contains() { # haystack needle
  if [[ "$1" != *"$2"* ]]; then _ok; else _bad "expected output NOT to contain '$2'"; fi
}

assert_file() { # path
  if [[ -e "$1" ]]; then _ok; else _bad "expected '$1' to exist"; fi
}

assert_no_file() { # path
  if [[ ! -e "$1" ]]; then _ok; else _bad "expected '$1' NOT to exist"; fi
}

# ── Scratch space ───────────────────────────────────────────────────────────
SCRATCH="$(mktemp -d)"
export SCRATCH
trap 'rm -rf "$SCRATCH"' EXIT

# ── Run ─────────────────────────────────────────────────────────────────────
if (($#)); then
  FILES=("$TESTS_DIR/$1")
else
  FILES=("$TESTS_DIR"/test-*.sh)
fi

for file in "${FILES[@]}"; do
  [[ -r "$file" ]] || { printf "no such test file: %s\n" "$file" >&2; exit 2; }
  printf "\n%s%s%s\n" "$BOLD" "$(basename "$file")" "$RESET"
  # shellcheck source=/dev/null
  source "$file"
done

printf "\n%s%d passed%s · %s%d failed%s\n" "$GREEN" "$T_PASS" "$RESET" "$RED" "$T_FAIL" "$RESET"
[[ "$T_FAIL" -eq 0 ]] || exit 1
