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
LINKS=(
  "ssh/config|$HOME/.ssh/config"
  "fish/conf.d|$HOME/.config/fish/conf.d"
  "fish/functions|$HOME/.config/fish/functions"
  "fish/config.fish|$HOME/.config/fish/config.fish"
  "starship/starship.toml|$HOME/.config/starship.toml"
  "git/config|$HOME/.config/git/config"
  "micro/settings.json|$HOME/.config/micro/settings.json"
  "bat/themes|$HOME/.config/bat/themes"
  "finicky/finicky.ts|$HOME/.config/finicky/finicky.ts"
  "claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "claude/settings.json|$HOME/.claude/settings.json"
  "claude/statusline.sh|$HOME/.claude/statusline.sh"
  "btop/btop.conf|$HOME/.config/btop/btop.conf"
  "gh/config.yml|$HOME/.config/gh/config.yml"
)
for entry in "${LINKS[@]}"; do
  src="$DOTFILES/${entry%%|*}"; dest="${entry#*|}"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    pass "${dest/#$HOME/~}"
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

# ── Summary ─────────────────────────────────────────────────────────────────
head "📋 Summary"
printf "  %s%d passed%s · %s%d warnings%s · %s%d failed%s\n" \
  "$GREEN" "$PASS" "$RESET" "$YELLOW" "$WARN" "$RESET" "$RED" "$FAIL" "$RESET"
[[ "$FAIL" -eq 0 ]] || exit 1
