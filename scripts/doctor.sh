#!/bin/bash
################################################################################
# Dotfiles Doctor
#
# Description:
#   Health check for the dotfiles environment. Verifies that required tools are
#   installed, that the symlinks resolve, and that the machine-specific bits
#   (default shell, 1Password agent, private SSH config) are in place.
#
#   Read-only where it counts: it creates, moves and rewrites nothing under
#   ~/.config, ~/.claude, ~/.ssh or ~/.local/bin, which scripts/tests/test-doctor.sh
#   asserts. It does ask brew for the outdated list, and brew writes its own caches
#   while answering. That is brew's bookkeeping, not a change to anything here.
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
# One entry per formula the Brewfile declares, named by the binary it provides:
# poppler's is pdftotext, every other name matches its formula. A formula absent
# from here gets installed by `make brew` and then never checked again.
REQUIRED=(bat btop eza fd fish fnm fzf gh jq lolcat micro mole node pdftotext pyenv starship terraform zoxide)
for bin in "${REQUIRED[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    pass "$bin"
  else
    fail "$bin not found. Run 'make brew'"
  fi
done

# git arrives with the Xcode command line tools and is not in the Brewfile, so
# `make brew` cannot be the remedy for it.
if command -v git >/dev/null 2>&1; then
  pass "git"
else
  fail "git not found. Run 'xcode-select --install'"
fi

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
    warn "${dest/#$HOME/~} exists but is not a symlink. Run 'make link'"
  else
    fail "${dest/#$HOME/~} missing. Run 'make link'"
  fi
done

# ── Machine-specific setup ──────────────────────────────────────────────────
head "⚙️  Environment"

# The account's login shell, read from the directory service rather than from
# $SHELL: that variable is inherited from whatever launched this, so a doctor run
# from a different shell reported a correctly configured machine as unconfigured.
FISH_PATH="$(command -v fish || true)"
LOGIN_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
if [[ -z "$LOGIN_SHELL" ]]; then
  warn "could not read the login shell, dscl returned nothing"
elif [[ -n "$FISH_PATH" && "$LOGIN_SHELL" == "$FISH_PATH" ]]; then
  pass "login shell is fish ($LOGIN_SHELL)"
else
  warn "login shell is '$LOGIN_SHELL', not fish. Run 'make default-shell'"
fi

OP_SIGN="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
if [[ -x "$OP_SIGN" ]]; then
  pass "1Password op-ssh-sign present (commit signing)"
else
  warn "1Password op-ssh-sign not found. Install 1Password & enable the SSH agent"
fi

# The directory as well as the file in it. install.sh enforces 0700 on every run, so
# a looser mode means something outside this repo widened it, and the directory itself
# lists your private hostnames.
if [[ -d "$HOME/.ssh" ]]; then
  SSH_DIR_MODE="$(stat -f '%Lp' "$HOME/.ssh" 2>/dev/null)"
  if [[ "$SSH_DIR_MODE" == "700" ]]; then
    pass "~/.ssh is 0700"
  else
    warn "~/.ssh is mode ${SSH_DIR_MODE:-unknown}, not 0700. Run 'make link'"
  fi
else
  warn "~/.ssh missing. Run 'make link'"
fi

if [[ -e "$HOME/.ssh/config.private" ]]; then
  # It holds private hostnames, and install.sh promises 0600, so report the mode
  # rather than mere existence, or a world-readable one passes unnoticed.
  MODE="$(stat -f '%Lp' "$HOME/.ssh/config.private" 2>/dev/null)"
  if [[ "$MODE" == "600" ]]; then
    pass "~/.ssh/config.private exists (0600)"
  else
    warn "~/.ssh/config.private is mode ${MODE:-unknown}, not 0600. Run 'make link'"
  fi
else
  warn "~/.ssh/config.private missing. Run 'make link'"
fi

# ── Homebrew maintenance ────────────────────────────────────────────────────
# The pull half of the maintenance reminder. The fish greeting only ever reports
# the age of the last run, because anything more costs real time at every shell
# start. Here the expensive question is affordable, so this is where it is asked.
head "🍺 Homebrew maintenance"
STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/brew-maintenance/last-run"
NUDGE_DAYS=7

if [[ -r "$STAMP" ]]; then
  AGE_DAYS=$(( ( $(date +%s) - $(stat -f %m "$STAMP") ) / 86400 ))
  if (( AGE_DAYS < NUDGE_DAYS )); then
    pass "last run $AGE_DAYS day(s) ago"
  else
    warn "last run $AGE_DAYS day(s) ago. Run 'bm'"
  fi
else
  warn "never run on this machine. Run 'bm'"
fi

if command -v brew >/dev/null 2>&1; then
  # Homebrew touches this after every update check, so its mtime dates the
  # package index. See Library/Homebrew/cmd/update.sh, "Touch FETCH_HEAD to
  # confirm we've checked for an update". It dates the index and not the
  # maintenance run, since an auto-update from any `brew install` touches it too.
  FETCH_HEAD="${HOMEBREW_REPOSITORY:-/opt/homebrew}/.git/FETCH_HEAD"
  if [[ -f "$FETCH_HEAD" ]]; then
    INDEX_DAYS=$(( ( $(date +%s) - $(stat -f %m "$FETCH_HEAD") ) / 86400 ))
    if (( INDEX_DAYS < NUDGE_DAYS )); then
      pass "package index refreshed $INDEX_DAYS day(s) ago"
    else
      warn "package index is $INDEX_DAYS day(s) stale, so counts below may lag"
    fi
  fi

  # HOMEBREW_NO_AUTO_UPDATE is what makes this free: `brew outdated` then compares
  # the Cellar against the already-cached API index, touching neither the network
  # nor any cache file. It still costs ~0.5s, which is why it lives here and not
  # in the shell greeting.
  if command -v jq >/dev/null 2>&1; then
    OUTDATED_JSON="$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json 2>/dev/null)"
    # Tested for emptiness before it is trusted. `printf '' | jq '.casks | length'`
    # exits 0 with no output, so the `|| echo 0` fallback never fired and a brew that
    # failed outright was reported as a machine with nothing outdated. Saying "all
    # clear" on the strength of an answer that never arrived is the one outcome a
    # health check must not produce.
    if [[ -z "$OUTDATED_JSON" ]]; then
      warn "could not read the outdated list, 'brew outdated' returned nothing"
    else
      N_FORMULAE="$(printf '%s' "$OUTDATED_JSON" | jq -r '.formulae | length' 2>/dev/null)"
      N_CASKS="$(printf '%s' "$OUTDATED_JSON" | jq -r '.casks | length' 2>/dev/null)"
      TOTAL=$(( ${N_FORMULAE:-0} + ${N_CASKS:-0} ))
      if (( TOTAL == 0 )); then
        pass "nothing outdated"
      else
        warn "$N_FORMULAE formula(e) and $N_CASKS cask(s) outdated. Run 'bm'"
      fi

      # Reported apart, and never as work to do. These carry their own updaters, so
      # brew's recorded version trails the one on disk. See brew-maintenance.
      #
      # The plain cask names are subtracted first, because
      # `--greedy-auto-updates` returns them too: the flag only disables the
      # `auto_updates` short circuit in Homebrew's Cask#outdated_version, so its
      # output is the ordinary list plus the self-updating ones. Counted whole, this
      # line contradicted the warning printed just above it, calling the very cask it
      # had flagged as outdated a cask that needs nothing.
      PLAIN_CASKS="$(printf '%s' "$OUTDATED_JSON" | jq -c '[.casks[]?.name]' 2>/dev/null)"
      [[ -n "$PLAIN_CASKS" ]] || PLAIN_CASKS='[]'
      N_GREEDY="$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --greedy-auto-updates --json 2>/dev/null \
        | jq -r --argjson plain "$PLAIN_CASKS" \
          '[.casks[]? | .name as $n | select(($plain | index($n)) == null)] | length' 2>/dev/null)"
      if (( ${N_GREEDY:-0} > 0 )); then
        pass "${N_GREEDY} cask(s) update themselves ${DIM}(brew's record trails on purpose)${RESET}"
      else
        pass "no self-updating casks"
      fi
    fi
  else
    warn "jq not found, skipping the outdated counts"
  fi
else
  fail "brew not found. Install Homebrew first"
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
    fail "venv exists but piper-tts is not in it. Re-run 'make speak-setup'"
  fi
  # A voice is two files: piper aborts without the sidecar .onnx.json, and the
  # download is not atomic, so half-arrived voices are a real state.
  shopt -s nullglob
  models=("$HOME/.local/share/piper/voices/"*.onnx)
  shopt -u nullglob
  # The count guard is not decoration: in bash 3.2 an empty array expands to an
  # unbound variable under `set -u`, which killed this script outright on the one
  # machine state that matters most, a venv with no voices yet.
  complete=0
  if ((${#models[@]} > 0)); then
    for m in "${models[@]}"; do [[ -r "$m.json" ]] && complete=$((complete + 1)); done
  fi
  if ((${#models[@]} == 0)); then
    warn "no voice models. Run 'make speak-setup'"
  elif ((complete == ${#models[@]})); then
    pass "$complete voice model(s) installed"
  else
    # Report the shortfall rather than the successes: a green count next to a voice
    # that cannot speak is worse than no count at all.
    fail "$((${#models[@]} - complete)) of ${#models[@]} voice model(s) missing their .onnx.json. Re-run 'make speak-setup'"
  fi
  # The Stop hook pipes every reply through python3 and swallows the failure, so
  # a broken interpreter means replies are silently never saved.
  if python3 -c 'import json, re' >/dev/null 2>&1; then
    pass "python3 can run the reply cleaner"
  else
    fail "python3 cannot import json/re, replies will never be prepared"
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
  warn "Piper not installed. Run 'make speak-setup' (optional feature)"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
head "📋 Summary"
printf "  %s%d passed%s · %s%d warnings%s · %s%d failed%s\n" \
  "$GREEN" "$PASS" "$RESET" "$YELLOW" "$WARN" "$RESET" "$RED" "$FAIL" "$RESET"
[[ "$FAIL" -eq 0 ]] || exit 1
