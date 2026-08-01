#!/usr/bin/env bash
################################################################################
# Tests for fish/functions/brew_nudge.fish
#
# Drives the reminder through fish with a fake stamp whose mtime is set by
# `touch -t`, which is the only input the function has. Nothing here reads the
# real cache directory, so the tests cannot be coloured by when maintenance
# actually last ran on this machine.
################################################################################

if ! command -v fish >/dev/null 2>&1; then
  it "fish is installed (skipping the nudge tests without it)"
  _bad "fish not found"
  return 0
fi

NUDGE="$DOTFILES/fish/functions/brew_nudge.fish"

# Runs brew_nudge with XDG_CACHE_HOME pointed at a scratch tree. `type -q brew`
# guards the real function, so the fake needs to be findable as a command.
nudge_run() { # cache_dir [fish statements before the call]
  local cache=$1; shift
  OUT="$(env XDG_CACHE_HOME="$cache" PATH="$FAKEBIN:$PATH" \
    fish --no-config -c "source '$NUDGE'; $*; brew_nudge" 2>/dev/null)"
}

# Age is expressed by setting the stamp's mtime, since that is what the function
# reads. Computed here rather than hardcoded so the tests do not rot.
stamp_aged() { # dir days
  mkdir -p "$1/brew-maintenance"
  local when
  when="$(date -v-"$2"d +%Y%m%d%H%M 2>/dev/null)"
  touch -t "$when" "$1/brew-maintenance/last-run"
}

FAKEBIN="$(mktemp -d "$SCRATCH/bin.XXXXXX")"
printf '#!/bin/sh\nexit 0\n' >"$FAKEBIN/brew"
chmod +x "$FAKEBIN/brew"

# ── No stamp at all ─────────────────────────────────────────────────────────
EMPTY="$(mktemp -d "$SCRATCH/empty.XXXXXX")"
nudge_run "$EMPTY"
it "with no stamp it says maintenance has never run"
assert_contains "$OUT" "never run"

# ── Fresh stamp stays quiet ─────────────────────────────────────────────────
FRESH="$(mktemp -d "$SCRATCH/fresh.XXXXXX")"
stamp_aged "$FRESH" 1
nudge_run "$FRESH"
it "a one-day-old run prints nothing"
assert_eq "" "$OUT"

SIX="$(mktemp -d "$SCRATCH/six.XXXXXX")"
stamp_aged "$SIX" 6
nudge_run "$SIX"
it "six days is still under the default threshold, so it stays quiet"
assert_eq "" "$OUT"

# ── Past the threshold it speaks, once, in one line ─────────────────────────
OLD="$(mktemp -d "$SCRATCH/old.XXXXXX")"
stamp_aged "$OLD" 9
nudge_run "$OLD"
it "nine days is overdue, so it suggests the command"
assert_contains "$OUT" "9 days ago"

it "the reminder names the two-letter alias"
assert_contains "$OUT" "bm"

it "the reminder is a suggestion, never an action"
assert_contains "$OUT" "Suggested"

it "the reminder is a single line, so the greeting stays compact"
assert_eq 1 "$(printf '%s\n' "$OUT" | grep -c .)"

# ── The threshold is tunable, and zero switches it off ──────────────────────
nudge_run "$OLD" "set -g brew_nudge_days 14"
it "raising the threshold above the age silences it"
assert_eq "" "$OUT"

nudge_run "$OLD" "set -g brew_nudge_days 0"
it "a threshold of zero disables the reminder entirely"
assert_eq "" "$OUT"

nudge_run "$OLD" "set -g brew_nudge_days 3"
it "lowering the threshold below the age brings it back"
assert_contains "$OUT" "9 days ago"

# ── Without brew there is nothing to suggest ────────────────────────────────
OUT="$(env XDG_CACHE_HOME="$OLD" PATH="/usr/bin:/bin" \
  fish --no-config -c "source '$NUDGE'; brew_nudge" 2>/dev/null)"
it "with no brew on PATH it stays silent instead of advertising a missing tool"
assert_eq "" "$OUT"

# ── It must not be the thing that slows the shell down ──────────────────────
# 200 iterations, so the per-call cost is readable above process startup noise.
# Budget is deliberately loose: the measured cost is 0.24 ms in a clean environment,
# and the assertion only has to catch a regression that reintroduces a `brew` call or
# a network hop. It runs under whatever environment the suite inherits, so the figure
# it prints is an upper bound rather than the number quoted in brew_nudge.fish.
ELAPSED_MS="$(env XDG_CACHE_HOME="$OLD" PATH="$FAKEBIN:$PATH" fish --no-config -c "
  source '$NUDGE'
  set -l t0 (python3 -c 'import time;print(int(time.time()*1000))')
  for i in (seq 200); brew_nudge >/dev/null; end
  set -l t1 (python3 -c 'import time;print(int(time.time()*1000))')
  math \"(\$t1 - \$t0) / 200\"
" 2>/dev/null)"
it "the reminder costs under 5 ms per call (measured: ${ELAPSED_MS:-?} ms)"
if [[ -n "$ELAPSED_MS" ]] && awk "BEGIN{exit !($ELAPSED_MS < 5)}"; then
  _ok
else
  _bad "expected under 5 ms per call, measured '${ELAPSED_MS:-nothing}'"
fi
