#!/bin/bash
################################################################################
# Spoken Claude Code replies: setup
#
# Description:
#   Installs Kokoro (a local neural text-to-speech engine) into its own venv and
#   downloads the model, so Claude Code can read its replies out loud. Everything
#   runs offline and free: no API keys, no quotas, no network at speaking time.
#   Idempotent. Re-run it any time, it only does what's missing.
#
#   The model lives outside the repo (~/.local/share/kokoro, ~340 MB) because
#   model blobs have no business in version control.
#
#   Runs on onnxruntime rather than torch: same model and same voices, but it
#   loads in 0.5 s instead of 5.5 s, and a venv of 155 MB instead of 993 MB. That
#   load happens once per reply, so it is the difference between speaking and
#   waiting.
#
# Usage:
#   ./scripts/speak-setup.sh   |   make speak-setup
################################################################################

set -euo pipefail

KOKORO_HOME="$HOME/.local/share/kokoro"
VENV="$KOKORO_HOME/venv"
MODEL="$KOKORO_HOME/kokoro-v1.0.onnx"
VOICES="$KOKORO_HOME/voices-v1.0.bin"
RELEASE="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
DEFAULT_VOICE="em_alex"

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

head "🐍 Kokoro virtualenv"
if [[ -x "$VENV/bin/python" ]]; then
  ok "${VENV/#$HOME/~} ${DIM}(already exists)${RESET}"
else
  command -v python3 >/dev/null 2>&1 || {
    warn "python3 not found. Install it first (pyenv is in the Brewfile)"
    exit 1
  }
  mkdir -p "$KOKORO_HOME"
  python3 -m venv "$VENV"
  ok "created ${VENV/#$HOME/~}"
fi

head "📦 kokoro-onnx"
if "$VENV/bin/python" -c 'import kokoro_onnx' >/dev/null 2>&1; then
  ok "kokoro-onnx ${DIM}(already installed)${RESET}"
else
  info "installing kokoro-onnx (this pulls onnxruntime, ~150 MB)…"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet kokoro-onnx
  ok "kokoro-onnx installed"
fi

# The grapheme-to-phoneme front end. The copy bundled in the espeakng-loader wheel
# has its data directory baked in at build time, pointing at the machine that built
# it, so it dies on a missing phontab: Homebrew's is the one that works.
head "🔤 espeak-ng"
if [[ -r /opt/homebrew/lib/libespeak-ng.dylib ]]; then
  ok "libespeak-ng ${DIM}(Homebrew)${RESET}"
else
  warn "espeak-ng missing. Run 'brew install espeak-ng', nothing will speak without it"
fi

head "🗣️  Voice model"
mkdir -p "$KOKORO_HOME"
# One model file holds all 54 voices, so unlike a per-voice download there is no
# half-installed state where a named voice silently does not exist. Downloaded to a
# temp name and moved into place, so an interrupted run re-downloads instead of
# leaving a truncated model that fails deep inside onnxruntime.
for pair in "$MODEL|kokoro-v1.0.onnx" "$VOICES|voices-v1.0.bin"; do
  dest="${pair%%|*}"; name="${pair##*|}"
  if [[ -r "$dest" ]]; then
    ok "$name ${DIM}(already downloaded)${RESET}"
  else
    info "downloading ${name}…"
    if curl -fsSL -o "$dest.part" "$RELEASE/$name"; then
      mv "$dest.part" "$dest"
      ok "$name"
    else
      rm -f "$dest.part"
      warn "could not download $name"
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
echo "    ${DIM}voice=${DEFAULT_VOICE}${RESET}   ${DIM}(54 in the model: em_santa, ef_dora, …)${RESET}"
echo "    ${DIM}speed=1.0${RESET}       ${DIM}above 1 is faster, below is slower${RESET}"
