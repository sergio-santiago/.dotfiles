#!/usr/bin/env bash
################################################################################
# Tests for fish/functions/claude-settings-fix.fish
#
# Each case gets a throwaway $HOME and a fake `claude` first on PATH that only
# records the directory it was started in and the prompt it was given. Nothing
# here touches the real ~/.claude or starts a real session. The repo copy of
# settings.json is only read, never written.
################################################################################

if ! command -v fish >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  it "fish and jq are installed (skipping the settings-fix tests without them)"
  _bad "fish or jq not found"
  return 0
fi

FIX="$DOTFILES/fish/functions/claude-settings-fix.fish"
TARGET="$DOTFILES/claude/settings.json"

FAKEBIN="$(mktemp -d "$SCRATCH/bin.XXXXXX")"
cat >"$FAKEBIN/claude" <<'EOF'
#!/bin/sh
pwd >"$CLAUDE_LOG.cwd"
printf '%s' "$1" >"$CLAUDE_LOG.prompt"
EOF
chmod +x "$FAKEBIN/claude"

# Runs the function with HOME pointed at $1. Sets OUT, and CWD/PROMPT when the
# fake claude was started (empty when it was not).
fix_run() { # home
  local log="$1/claude-log"
  OUT="$(env HOME="$1" CLAUDE_LOG="$log" PATH="$FAKEBIN:$PATH" \
    fish --no-config -c "source '$FIX'; claude-settings-fix" 2>&1)"
  CWD="$(cat "$log.cwd" 2>/dev/null)"
  PROMPT="$(cat "$log.prompt" 2>/dev/null)"
}

new_home() { local h; h="$(mktemp -d "$SCRATCH/home.XXXXXX")"; mkdir -p "$h/.claude"; echo "$h"; }

# ── Intact link: says so and starts nothing ─────────────────────────────────
H="$(new_home)"
ln -s "$TARGET" "$H/.claude/settings.json"
fix_run "$H"
it "an intact link reports nothing to fix"
assert_contains "$OUT" "nothing to fix"
it "an intact link does not start claude"
assert_eq "" "$CWD"

# ── Plain file with an extra key: session in the repo, diff in the prompt ───
H="$(new_home)"
jq '. + {"addedOnlyHere": true}' "$TARGET" >"$H/.claude/settings.json"
fix_run "$H"
it "a plain file starts claude in the repo"
assert_eq "$DOTFILES" "$CWD"
it "the prompt says it is a plain file"
assert_contains "$PROMPT" "a plain file"
it "the prompt carries the key that only the live copy has"
assert_contains "$PROMPT" '+  "addedOnlyHere": true'
it "the prompt asks to wait for an OK before changing anything"
assert_contains "$PROMPT" "wait for my OK"

# ── Same content in another format: no false diff ───────────────────────────
H="$(new_home)"
jq -S . "$TARGET" | sed 's/": /" : /' >"$H/.claude/settings.json"
fix_run "$H"
it "a reformatted copy with the same keys shows no key difference"
assert_contains "$PROMPT" "only the format differs"

# ── Link to somewhere else ──────────────────────────────────────────────────
H="$(new_home)"
cp "$TARGET" "$H/elsewhere.json"
ln -s "$H/elsewhere.json" "$H/.claude/settings.json"
fix_run "$H"
it "a link that points outside the repo counts as broken"
assert_contains "$PROMPT" "not to the repo"
