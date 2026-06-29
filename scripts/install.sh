#!/bin/bash
################################################################################
# Dotfiles Installer
#
# Description:
#   Idempotent installer that symlinks every config into ~/.config, ~/.claude
#   and ~/.ssh. Safe to re-run: existing files are backed up (with timestamp)
#   before linking, and links already pointing to the right place are skipped.
#   Also creates ~/.ssh/config.private (0600) and rebuilds the bat theme cache.
#
# Usage:
#   ./scripts/install.sh   |   make link
################################################################################

set -euo pipefail

# Repo root = parent of this script's directory, resolved to an absolute path.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ── Pretty output ───────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'
  BLUE=$'\033[38;2;104;213;255m'; RED=$'\033[38;2;255;77;77m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""; RED=""
fi
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
info() { printf "  %s→%s %s\n" "$BLUE" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }

# ── Symlink map: "<relative-source>|<absolute-destination>" ─────────────────
LINKS=(
  "ssh/config|$HOME/.ssh/config"
  "fish/conf.d|$HOME/.config/fish/conf.d"
  "fish/functions|$HOME/.config/fish/functions"
  "fish/config.fish|$HOME/.config/fish/config.fish"
  "starship/starship.toml|$HOME/.config/starship.toml"
  "git/config|$HOME/.config/git/config"
  "micro/settings.json|$HOME/.config/micro/settings.json"
  "micro/colorschemes/linked-data-dark-rainbow.micro|$HOME/.config/micro/colorschemes/linked-data-dark-rainbow.micro"
  "bat/themes|$HOME/.config/bat/themes"
  "finicky/finicky.ts|$HOME/.config/finicky/finicky.ts"
  "claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "claude/settings.json|$HOME/.claude/settings.json"
  "claude/statusline.sh|$HOME/.claude/statusline.sh"
  "btop/btop.conf|$HOME/.config/btop/btop.conf"
  "gh/config.yml|$HOME/.config/gh/config.yml"
)

link_one() {
  local src="$DOTFILES/$1" dest="$2"

  if [[ ! -e "$src" ]]; then
    warn "source missing, skipping: $1"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  # Already linked correctly → nothing to do.
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    ok "${dest/#$HOME/~} ${DIM}(already linked)${RESET}"
    return
  fi

  # Something is in the way → back it up before replacing.
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="$BACKUP_DIR$dest"
    mkdir -p "$(dirname "$backup")"
    mv "$dest" "$backup"
    warn "backed up ${dest/#$HOME/~} → ${backup/#$HOME/~}"
  fi

  ln -sfh "$src" "$dest"
  ok "${dest/#$HOME/~} → ${src/#$HOME/~}"
}

# ── Run ─────────────────────────────────────────────────────────────────────
head "🔗 Symlinking dotfiles"
info "repo:   ${DOTFILES/#$HOME/~}"
info "backup: ${BACKUP_DIR/#$HOME/~} ${DIM}(only created if needed)${RESET}"
for entry in "${LINKS[@]}"; do
  link_one "${entry%%|*}" "${entry#*|}"
done

# Private SSH config: referenced by ssh/config but kept out of version control.
head "🔐 Private SSH config"
if [[ ! -e "$HOME/.ssh/config.private" ]]; then
  mkdir -p "$HOME/.ssh"
  touch "$HOME/.ssh/config.private"
  chmod 600 "$HOME/.ssh/config.private"
  ok "created ~/.ssh/config.private (0600) — add machine-specific hosts here"
else
  ok "~/.ssh/config.private already exists"
fi

# Bat theme cache: needs rebuilding for the custom theme to be selectable.
head "🦇 Bat theme cache"
if command -v bat >/dev/null 2>&1; then
  bat cache --build >/dev/null && ok "bat cache rebuilt"
else
  warn "bat not installed — run 'make brew' first, then 'bat cache --build'"
fi

head "✅ Done"
echo "  Next steps:"
echo "    • Set Fish as your default shell:   ${BOLD}make default-shell${RESET}"
echo "    • Enable the 1Password SSH agent:   1Password → Settings → Developer"
echo "    • Verify the setup:                 ${BOLD}make doctor${RESET}"
