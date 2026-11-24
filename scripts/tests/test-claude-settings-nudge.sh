#!/usr/bin/env bash
################################################################################
# Tests for fish/functions/claude_settings_nudge.fish
#
# Each case gets a throwaway $HOME whose ~/.claude/settings.json is a correct
# link, a plain file, a link elsewhere or missing. The repo copy is only read.
################################################################################

if ! command -v fish >/dev/null 2>&1; then
  it "fish is installed (skipping the settings nudge tests without it)"
  _bad "fish not found"
  return 0
fi

NUDGE="$DOTFILES/fish/functions/claude_settings_nudge.fish"
TARGET="$DOTFILES/claude/settings.json"

nudge_run() { # home [extra env]
  local h=$1; shift
  OUT="$(env HOME="$h" "$@" fish --no-config -c "source '$NUDGE'; claude_settings_nudge" 2>&1)"
}

new_home() { local h; h="$(mktemp -d "$SCRATCH/home.XXXXXX")"; mkdir -p "$h/.claude"; echo "$h"; }

# ── Quiet paths ─────────────────────────────────────────────────────────────
H="$(new_home)"
ln -s "$TARGET" "$H/.claude/settings.json"
nudge_run "$H"
it "an intact link prints nothing"
assert_eq "" "$OUT"

H="$(new_home)"
nudge_run "$H"
it "with no settings.json at all it prints nothing (Claude Code not set up)"
assert_eq "" "$OUT"

# ── Broken link speaks, once, in one line ───────────────────────────────────
BROKEN="$(new_home)"
cp "$TARGET" "$BROKEN/.claude/settings.json"
nudge_run "$BROKEN"
it "a plain file names the command that repairs it"
assert_contains "$OUT" "claude-settings-fix"

it "the reminder is a single line after its blank row"
assert_eq 1 "$(printf '%s\n' "$OUT" | grep -c .)"

it "the reminder opens with a blank row, like the Homebrew one"
assert_eq "" "$(printf '%s\n' "$OUT" | head -1)"

it "the reminder has its own emoji, not the Homebrew one"
assert_contains "$OUT" "🔗"

H="$(new_home)"
cp "$TARGET" "$H/elsewhere.json"
ln -s "$H/elsewhere.json" "$H/.claude/settings.json"
nudge_run "$H"
it "a link that points outside the repo also counts as broken"
assert_contains "$OUT" "claude-settings-fix"

# The rule colour is what tells this reminder apart from brew_nudge's orange.
it "the rule uses the palette's pink and the command its cyan"
COLORED="$(env HOME="$BROKEN" TERM=xterm-256color \
  fish --no-config -c "source '$NUDGE'; claude_settings_nudge | cat -v" 2>/dev/null)"
if [[ "$COLORED" == *"255;108;212"* && "$COLORED" == *"127;255;212"* ]]; then
  _ok
else
  _bad "expected pink ff6cd4 on the rule and cyan 7fffd4 on the command, got: $COLORED"
fi

# ── It must not be the thing that slows the shell down ──────────────────────
# Same loose budget and method as test-brew-nudge.sh. Measured on the broken
# path, which does the most work.
ELAPSED_MS="$(env HOME="$BROKEN" fish --no-config -c "
  source '$NUDGE'
  set -l t0 (python3 -c 'import time;print(int(time.time()*1000))')
  for i in (seq 200); claude_settings_nudge >/dev/null; end
  set -l t1 (python3 -c 'import time;print(int(time.time()*1000))')
  math \"(\$t1 - \$t0) / 200\"
" 2>/dev/null)"
it "the reminder costs under 5 ms per call (measured: ${ELAPSED_MS:-?} ms)"
if [[ -n "$ELAPSED_MS" ]] && awk "BEGIN{exit !($ELAPSED_MS < 5)}"; then
  _ok
else
  _bad "expected under 5 ms per call, measured '${ELAPSED_MS:-nothing}'"
fi
