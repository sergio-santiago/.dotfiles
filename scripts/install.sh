#!/bin/bash
################################################################################
# Dotfiles Installer
#
# Description:
#   Idempotent installer that symlinks every config into ~/.config, ~/.claude,
#   ~/.ssh and ~/.local/bin. Safe to re-run: existing files are backed up (timestamped)
#   before linking, and links already pointing to the right place are skipped.
#   Also creates ~/.ssh/config.private (0600) and rebuilds the bat theme cache.
#
#   --dry-run prints the same run without performing any of it, so a new machine
#   can be inspected before anything in $HOME is touched.
#
# Usage:
#   ./scripts/install.sh [--dry-run]   |   make link   |   make link-dry
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
# Planned, not done. A dim arrow rather than the green tick every other line uses,
# so a dry run cannot be mistaken at a glance for a real one.
plan() { printf "  %s→ would %s%s\n" "$DIM" "$1" "$RESET"; }

# ── Arguments ───────────────────────────────────────────────────────────────
DRY=0

usage() {
  cat <<EOF
${BOLD}install.sh${RESET} - symlink every config into \$HOME

  -n, --dry-run   print what would happen and change nothing
  -h, --help      this text

Idempotent either way: anything it would overwrite is moved to
~/.dotfiles-backup/<timestamp>/ first, and links already correct are left alone.
EOF
}

while (($#)); do
  case "$1" in
    -n|--dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf "unknown option: %s\n\n" "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ── Symlink map ─────────────────────────────────────────────────────────────
# Shared with doctor.sh, which verifies what this creates. See scripts/links.sh.
# shellcheck source=links.sh
source "$(dirname "${BASH_SOURCE[0]}")/links.sh"

# Directories a dry run has already announced. See link_one.
PLANNED_DIRS=""

link_one() {
  local src="$DOTFILES/$1" dest="$2"

  if [[ ! -e "$src" ]]; then
    warn "source missing, skipping: $1"
    return
  fi

  # Checked before the directory is created, so a dry run reports the parent it
  # would have to make instead of quietly making it.
  local parent
  parent="$(dirname "$dest")"
  if [[ ! -d "$parent" ]]; then
    if ((DRY)); then
      # Announced once per directory. A dry run creates nothing, so the test above
      # stays true and every later entry under ~/.claude would report it again.
      # A string rather than an associative array: bash 3.2 has no declare -A.
      if [[ "$PLANNED_DIRS" != *"|$parent|"* ]]; then
        PLANNED_DIRS+="|$parent|"
        plan "create ${parent/#$HOME/~}"
      fi
    else
      mkdir -p "$parent"
    fi
  fi

  # Already linked correctly → nothing to do.
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    ok "${dest/#$HOME/~} ${DIM}(already linked)${RESET}"
    return
  fi

  # Something is in the way → back it up before replacing.
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="$BACKUP_DIR$dest"
    if ((DRY)); then
      plan "back up ${dest/#$HOME/~} → ${backup/#$HOME/~}"
    else
      mkdir -p "$(dirname "$backup")"
      mv "$dest" "$backup"
      warn "backed up ${dest/#$HOME/~} → ${backup/#$HOME/~}"
    fi
  fi

  if ((DRY)); then
    plan "link ${dest/#$HOME/~} → ${src/#$HOME/~}"
    return
  fi
  ln -sfh "$src" "$dest"
  ok "${dest/#$HOME/~} → ${src/#$HOME/~}"
}

# ── Run ─────────────────────────────────────────────────────────────────────
if ((DRY)); then
  head "🔍 Dry run ${DIM}(nothing below is performed)${RESET}"
fi

head "🔗 Symlinking dotfiles"
info "repo:   ${DOTFILES/#$HOME/~}"
info "backup: ${BACKUP_DIR/#$HOME/~} ${DIM}(only created if needed)${RESET}"
for entry in "${LINKS[@]}"; do
  link_one "${entry%%|*}" "${entry#*|}"
done

# Private SSH config: referenced by ssh/config but kept out of version control.
head "🔐 Private SSH config"
if ((DRY)); then
  # link_one already announced ~/.ssh while planning ssh/config, and a dry run never
  # creates it, so the -d test below stays false and the directory was named twice
  # under two different labels. Announced once, with the modes stated on their own
  # line, so the plan reads as the run it describes.
  [[ -d "$HOME/.ssh" || "$PLANNED_DIRS" == *"|$HOME/.ssh|"* ]] || plan "create ~/.ssh"
  [[ -e "$HOME/.ssh/config.private" ]] || plan "create ~/.ssh/config.private"
  plan "enforce 0700 on ~/.ssh and 0600 on ~/.ssh/config.private"
else
  mkdir -p "$HOME/.ssh"
  # The directory and not only the file inside it. link_one creates ~/.ssh with
  # whatever umask is in force, which on a fresh machine is 0755. ssh tolerates
  # that, the convention does not, and the directory lists your private hostnames.
  chmod 700 "$HOME/.ssh"
  if [[ ! -e "$HOME/.ssh/config.private" ]]; then
    touch "$HOME/.ssh/config.private"
    ok "created ~/.ssh/config.private. Add machine-specific hosts here"
  else
    ok "~/.ssh/config.private already exists"
  fi
  # Outside the branch above: the file holds private hostnames, and a mode set only
  # at creation is a mode nothing ever restores.
  chmod 600 "$HOME/.ssh/config.private"
  ok "modes enforced: ~/.ssh 0700, config.private 0600"
fi

# Bat theme cache: needs rebuilding for the custom theme to be selectable.
head "🦇 Bat theme cache"
if ! command -v bat >/dev/null 2>&1; then
  warn "bat not installed. Run 'make brew' first, then 'bat cache --build'"
elif ((DRY)); then
  plan "run 'bat cache --build'"
elif bat cache --build >/dev/null 2>&1; then
  ok "bat cache rebuilt"
else
  # A failure inside an && list is exempt from errexit, so without this branch the
  # script reaches "Done" with no cache and a zero exit status.
  warn "bat cache could not be rebuilt. Run 'bat cache --build' by hand"
fi

if ((DRY)); then
  head "🔍 Dry run finished"
  echo "  Nothing was changed. Run ${BOLD}make link${RESET} to apply the plan above."
  exit 0
fi

head "✅ Done"
echo "  Next steps:"
echo "    • Set Fish as your default shell:   ${BOLD}make default-shell${RESET}"
echo "    • Enable the 1Password SSH agent:   1Password → Settings → Developer"
echo "    • Verify the setup:                 ${BOLD}make doctor${RESET}"
