#!/bin/bash
################################################################################
# Dotfiles Doctor
#
# Description:
#   Health check for the dotfiles environment. Verifies that required tools are
#   installed, that the symlinks resolve, and that the machine-specific bits
#   (default shell, 1Password agent, private SSH config) are in place.
#   Read-only: it never changes anything.
#
# Usage:
#   ./scripts/doctor.sh   |   make doctor
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'; RED=$'\033[38;2;255;77;77m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""; RED=""
fi
PASS=0; WARN=0; FAIL=0
pass() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; PASS=$((PASS+1)); }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; WARN=$((WARN+1)); }
fail() { printf "  %s✗%s %s\n" "$RED" "$RESET" "$1"; FAIL=$((FAIL+1)); }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }

# ── Required CLI tools ──────────────────────────────────────────────────────
head "🛠️  CLI tools (from Brewfile)"
REQUIRED=(fish starship fzf fd bat eza zoxide micro btop jq gh git fnm pyenv lolcat)
for bin in "${REQUIRED[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    pass "$bin"
  else
    fail "$bin not found — run 'make brew'"
  fi
done

# ── Symlinks ────────────────────────────────────────────────────────────────
head "🔗 Symlinks"
# Shared with install.sh, which creates exactly what this verifies. See links.sh.
# shellcheck source=links.sh
source "$(dirname "${BASH_SOURCE[0]}")/links.sh"
for entry in "${LINKS[@]}"; do
  src="$DOTFILES/${entry%%|*}"; dest="${entry#*|}"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" && -e "$dest" ]]; then
    pass "${dest/#$HOME/~}"
  elif [[ -L "$dest" && ! -e "$dest" ]]; then
    # The -e above is what catches this: readlink hands back the stored path
    # whether or not anything is there, so a broken link looks identical to a good
    # one until you test the target.
    fail "${dest/#$HOME/~} → dangling, points at nothing ($(readlink "$dest"))"
  elif [[ -L "$dest" ]]; then
    warn "${dest/#$HOME/~} → points elsewhere ($(readlink "$dest"))"
  elif [[ -e "$dest" ]]; then
    warn "${dest/#$HOME/~} exists but is not a symlink — run 'make link'"
  else
    fail "${dest/#$HOME/~} missing — run 'make link'"
  fi
done

# ── Machine-specific setup ──────────────────────────────────────────────────
head "⚙️  Environment"

FISH_PATH="$(command -v fish || true)"
if [[ -n "$FISH_PATH" && "$SHELL" == "$FISH_PATH" ]]; then
  pass "default shell is fish ($SHELL)"
else
  warn "default shell is '$SHELL', not fish — run 'make default-shell'"
fi

OP_SIGN="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
if [[ -x "$OP_SIGN" ]]; then
  pass "1Password op-ssh-sign present (commit signing)"
else
  warn "1Password op-ssh-sign not found — install 1Password & enable the SSH agent"
fi

if [[ -e "$HOME/.ssh/config.private" ]]; then
  pass "~/.ssh/config.private exists"
else
  warn "~/.ssh/config.private missing — run 'make link'"
fi

# ── Spoken Claude Code replies (optional) ───────────────────────────────────
head "🔊 Spoken replies (optional)"
PIPER_PY="$HOME/.local/share/piper/venv/bin/python"

if [[ -x "$PIPER_PY" ]]; then
  # Importing is the real test. The venv is created before piper-tts goes into it,
  # so a failed pip leaves a python that runs perfectly and cannot speak a word.
  if "$PIPER_PY" -c 'import piper' >/dev/null 2>&1; then
    pass "Piper installed"
  else
    fail "venv exists but piper-tts is not in it — re-run 'make speak-setup'"
  fi
  # A voice is two files: piper aborts without the sidecar .onnx.json, and the
  # download is not atomic, so half-arrived voices are a real state.
  shopt -s nullglob
  models=("$HOME/.local/share/piper/voices/"*.onnx)
  shopt -u nullglob
  # The count guard is not decoration: in bash 3.2 an empty array expands to an
  # unbound variable under `set -u`, which killed this script outright on the one
  # machine state that matters most — a venv with no voices yet.
  complete=0
  if ((${#models[@]} > 0)); then
    for m in "${models[@]}"; do [[ -r "$m.json" ]] && complete=$((complete + 1)); done
  fi
  if ((${#models[@]} == 0)); then
    warn "no voice models — run 'make speak-setup'"
  elif ((complete == ${#models[@]})); then
    pass "$complete voice model(s) installed"
  else
    # Report the shortfall rather than the successes: a green count next to a voice
    # that cannot speak is worse than no count at all.
    fail "$((${#models[@]} - complete)) of ${#models[@]} voice model(s) missing their .onnx.json — re-run 'make speak-setup'"
  fi
  # The Stop hook pipes every reply through python3 and swallows the failure, so
  # a broken interpreter means replies are silently never saved.
  if python3 -c 'import json, re' >/dev/null 2>&1; then
    pass "python3 can run the reply cleaner"
  else
    fail "python3 cannot import json/re — replies will never be prepared"
  fi
  # Enabled is per console, so report how many consoles are currently speaking
  # rather than a single global state.
  shopt -s nullglob
  speaking=("$HOME/.claude/speak-consoles/"*)
  shopt -u nullglob
  if ((${#speaking[@]} > 0)); then
    pass "${#speaking[@]} console marker(s) ${DIM}('speak off' in each to silence)${RESET}"
  else
    pass "all consoles off ${DIM}(turn one on with 'speak on')${RESET}"
  fi
else
  warn "Piper not installed — run 'make speak-setup' (optional feature)"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
head "📋 Summary"
printf "  %s%d passed%s · %s%d warnings%s · %s%d failed%s\n" \
  "$GREEN" "$PASS" "$RESET" "$YELLOW" "$WARN" "$RESET" "$RED" "$FAIL" "$RESET"
[[ "$FAIL" -eq 0 ]] || exit 1
