#!/bin/bash
################################################################################
# Spoken Claude Code replies: setup
#
# Description:
#   Installs Piper (a local neural text-to-speech engine) into its own venv and
#   downloads the Spanish voices, so Claude Code can read its replies out loud.
#   Everything runs offline and free: no API keys, no quotas, no network at
#   speaking time. Idempotent. Re-run it any time, it only does what's missing.
#
#   The voices live outside the repo (~/.local/share/piper, ~140 MB of models)
#   because model blobs have no business in version control.
#
# Usage:
#   ./scripts/speak-setup.sh   |   make speak-setup
################################################################################

set -euo pipefail

PIPER_HOME="$HOME/.local/share/piper"
VENV="$PIPER_HOME/venv"
VOICES="$PIPER_HOME/voices"
MODELS=(es_ES-davefx-medium es_ES-sharvard-medium)

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'
  BLUE=$'\033[38;2;104;213;255m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
info() { printf "  %s→%s %s\n" "$BLUE" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }

head "🐍 Piper virtualenv"
if [[ -x "$VENV/bin/python" ]]; then
  ok "${VENV/#$HOME/~} ${DIM}(already exists)${RESET}"
else
  command -v python3 >/dev/null 2>&1 || {
    warn "python3 not found. Install it first (pyenv is in the Brewfile)"
    exit 1
  }
  mkdir -p "$PIPER_HOME"
  python3 -m venv "$VENV"
  ok "created ${VENV/#$HOME/~}"
fi

head "📦 piper-tts"
if "$VENV/bin/python" -c 'import piper' >/dev/null 2>&1; then
  ok "piper-tts ${DIM}(already installed)${RESET}"
else
  info "installing piper-tts (this pulls onnxruntime, ~100 MB)…"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet piper-tts
  ok "piper-tts installed"
fi

head "🗣️  Spanish voices"
mkdir -p "$VOICES"
for model in "${MODELS[@]}"; do
  # Both halves, not just the model: piper needs the sidecar JSON, and the
  # downloader fetches them in separate requests with no atomic rename, so an
  # interrupted run leaves a model that can never speak.
  if [[ -r "$VOICES/$model.onnx" && -r "$VOICES/$model.onnx.json" ]]; then
    ok "$model ${DIM}(already downloaded)${RESET}"
  else
    # Braces are load-bearing: bash 3.2 swallows the first byte of the following
    # multibyte character into the variable name, so "$model…" aborts the script
    # under `set -u` with "model\xe2: unbound variable", and this is the only
    # path that ever downloads anything.
    info "downloading ${model}…"
    if err="$("$VENV/bin/python" -m piper.download_voices \
        --data-dir "$VOICES" "$model" 2>&1 >/dev/null)"; then
      ok "$model"
    else
      # Not fatal, and not silent: a 404 or a dropped connection on one voice must
      # neither hide itself nor stop the other one from being fetched.
      warn "could not download $model: ${err:-no output from piper}"
    fi
  fi
done

head "✅ Done"
echo "  Turn it on and try it out:"
echo "    • ${BOLD}speak on${RESET}          arm this console ${DIM}(toggle it with plain 'speak')${RESET}"
echo "    • ${BOLD}speak test${RESET}        hear the current voice"
echo "    • ${BOLD}/speak summary${RESET}    read the last reply's summary · ${BOLD}/speak full${RESET} all of it"
echo "    • ${BOLD}speak stop${RESET}        shut up right now"
echo
echo "  Voice and speed live in ${BOLD}~/.claude/speak.conf${RESET}:"
echo "    ${DIM}voice=${MODELS[0]}${RESET}   ${DIM}(or ${MODELS[1]})${RESET}"
echo "    ${DIM}speed=1.0${RESET}                        ${DIM}below 1 is faster, above is slower${RESET}"
