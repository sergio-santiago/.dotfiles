#!/usr/bin/env bash
################################################################################
# Backup check: what still lives only on this disk
#
# Description:
#   Everything worth keeping should exist somewhere other than this disk. This
#   answers whether it does with a yes or a no instead of a memory exercise, which
#   is worth having before reinstalling macOS or whenever the disk could go.
#
#   check     read-only. Fails when any of these is true:
#               - a listed repo has uncommitted changes, stashes, commits on no
#                 remote, or no remote at all
#               - a file in the private map differs from the private repo, or the
#                 private repo itself is not committed and pushed
#               - the Claude Code memory of a listed repo differs from its snapshot
#             and warns, without failing, about launchd agents that run something
#             under $HOME, since those stop with the machine
#   snapshot  copies the Claude Code memory of every listed repo into the private
#             repo, under claude-memory/. `make private-push` then commits it
#
#   Which repos: ~/.dotfiles, the private repo, and whatever the private list at
#   ~/.config/backup-check/repos names, one path or glob per line, `~` allowed.
#   The list is private because the paths themselves say what you work on.
#
#   Commits "on no remote" are read from the last fetch, so nothing here touches
#   the network. A branch deleted on the remote after the last fetch still counts
#   as pushed until the next one.
#
# Usage:
#   ./scripts/backup-check.sh check      |   make backup-check
#   ./scripts/backup-check.sh snapshot   |   make memory-snapshot
#
#   Override the private repo with DOTFILES_PRIVATE=/some/path and the list with
#   BACKUP_CHECK_REPOS=/some/file.
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIVATE_REPO="${DOTFILES_PRIVATE:-$HOME/.dotfiles-private}"
REPO_LIST="${BACKUP_CHECK_REPOS:-$HOME/.config/backup-check/repos}"
CLAUDE_PROJECTS="$HOME/.claude/projects"
SNAPSHOT="$PRIVATE_REPO/claude-memory"

# shellcheck source=./private-files.sh
source "$DOTFILES/scripts/private-files.sh"

# ── Pretty output ───────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RESET=$'\033[0m'
  GREEN=$'\033[38;2;68;243;115m'; YELLOW=$'\033[38;2;255;236;153m'
  BLUE=$'\033[38;2;104;213;255m'; RED=$'\033[38;2;255;77;77m'
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""; RED=""
fi

FAILED=0; WARNED=0
ok()   { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
info() { printf "  %s→%s %s\n" "$BLUE" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; WARNED=$((WARNED + 1)); }
bad()  { printf "  %s✗%s %s\n" "$RED" "$RESET" "$1"; FAILED=$((FAILED + 1)); }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }

tilde() { printf '%s' "${1/#$HOME/~}"; }

# Claude Code names a project's folder after its absolute path, with every
# character that is not a letter or a digit turned into `-`.
slug() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# ── Which repos ─────────────────────────────────────────────────────────────
# Unquoted expansion on purpose, so a glob in the list matches. nullglob makes a
# pattern with no match vanish instead of being checked as a literal path.
list_repos() {
  local line path
  printf '%s\n' "$DOTFILES" "$PRIVATE_REPO"
  [[ -f "$REPO_LIST" ]] || return 0
  shopt -s nullglob
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    line="${line/#\~/$HOME}"
    # shellcheck disable=SC2086  # the glob has to expand
    for path in $line; do
      [[ -d "$path" ]] && printf '%s\n' "${path%/}"
    done
  done <"$REPO_LIST"
  shopt -u nullglob
}

REPOS=()
while IFS= read -r r; do
  [[ " ${REPOS[*]-} " == *" $r "* ]] || REPOS+=("$r")
done < <(list_repos)

memory_of() { printf '%s' "$CLAUDE_PROJECTS/$(slug "$1")/memory"; }

has_memory() { [[ -d "$1" && -n "$(ls -A "$1" 2>/dev/null)" ]]; }

# ── check ───────────────────────────────────────────────────────────────────
check_repos() {
  head "📁 Repositories"
  [[ -f "$REPO_LIST" ]] || info "no list at $(tilde "$REPO_LIST"), checking only the two dotfiles repos"

  local repo n issues
  for repo in "${REPOS[@]}"; do
    if [[ ! -d "$repo/.git" ]]; then
      [[ "$repo" == "$PRIVATE_REPO" ]] || bad "$(tilde "$repo") is not a git repository, so nothing in it is backed up"
      continue
    fi
    issues=()
    [[ -z "$(git -C "$repo" remote)" ]] && issues+=("no remote")
    n="$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')"
    ((n)) && issues+=("$n uncommitted change(s)")
    n="$(git -C "$repo" log --branches --not --remotes --oneline | wc -l | tr -d ' ')"
    ((n)) && issues+=("$n commit(s) on no remote")
    n="$(git -C "$repo" stash list | wc -l | tr -d ' ')"
    ((n)) && issues+=("$n stash(es)")
    if ((${#issues[@]})); then
      bad "$(tilde "$repo"): $(IFS=,; printf '%s' "${issues[*]}" | sed 's/,/, /g')"
    else
      ok "$(tilde "$repo")"
    fi
  done
}

check_private() {
  head "🔐 Private config"
  if [[ ! -d "$PRIVATE_REPO/.git" ]]; then
    bad "no private repo at $(tilde "$PRIVATE_REPO")"
    return
  fi

  local entry src dest drift=0
  for entry in "${PRIVATE_FILES[@]}"; do
    src="${entry%%|*}"; dest="$PRIVATE_REPO/${entry#*|}"
    [[ ! -f "$src" ]] && continue
    if ! cmp -s "$src" "$dest" 2>/dev/null; then
      bad "$(tilde "$src") differs from the private repo"; drift=1
    fi
  done
  ((drift)) || ok "every mapped file matches the private repo"
  ((drift)) && info "run 'make private-push'"
}

check_memory() {
  head "🧠 Claude Code memory"
  local repo mem snap any=0
  for repo in "${REPOS[@]}"; do
    mem="$(memory_of "$repo")"
    has_memory "$mem" || continue
    any=1
    snap="$SNAPSHOT/$(slug "$repo")/memory"
    if [[ ! -d "$snap" ]]; then
      bad "$(tilde "$repo") has memory with no snapshot"
    elif ! diff -rq "$mem" "$snap" >/dev/null 2>&1; then
      bad "$(tilde "$repo"): memory differs from its snapshot"
    else
      ok "$(tilde "$repo")"
    fi
  done
  ((any)) || ok "no listed repo has any memory"
}

check_agents() {
  head "⏱️  launchd agents"
  # Every argument and not just the first: an agent of your own is often an
  # interpreter in /usr/bin running a script under $HOME. Anything inside a .app
  # belongs to an installed app, which a new machine reinstalls on its own.
  local plist args own any=0
  shopt -s nullglob
  for plist in "$HOME"/Library/LaunchAgents/*.plist; do
    args="$( { plutil -extract ProgramArguments json -o - "$plist" 2>/dev/null
               plutil -extract Program json -o - "$plist" 2>/dev/null; } | sed 's#\\/#/#g')"
    own="$(grep -oE "\"$HOME/[^\"]*\"" <<<"$args" | tr -d '"' | grep -v '\.app/' | sed -n 1p)"
    [[ -n "$own" ]] || continue
    any=1
    warn "$(basename "$plist" .plist) runs $(tilde "$own") and stops with this machine"
  done
  shopt -u nullglob
  ((any)) || ok "none of your own"
}

check_pushed() {
  # Last, because every fix above ends in a private-push and this is what says it worked.
  [[ -d "$PRIVATE_REPO/.git" ]] || return
  head "📤 Private repo"
  if [[ -n "$(git -C "$PRIVATE_REPO" status --porcelain)" ]]; then
    bad "the private repo has uncommitted changes. Run 'make private-push'"
  elif ! git -C "$PRIVATE_REPO" remote get-url origin >/dev/null 2>&1; then
    bad "the private repo has no remote, so it dies with this machine"
  elif [[ -n "$(git -C "$PRIVATE_REPO" log --branches --not --remotes --oneline)" ]]; then
    bad "the private repo has commits on no remote. Run 'make private-push'"
  else
    ok "committed and pushed"
  fi
}

do_check() {
  check_repos
  check_private
  check_memory
  check_pushed
  check_agents

  head "📋 Summary"
  if ((FAILED)); then
    bad "$FAILED thing(s) still live only on this disk"
    exit 1
  fi
  ok "nothing found that lives only on this disk"
  ((WARNED)) && info "$WARNED warning(s) above: those stop if this machine does"
  exit 0
}

# ── snapshot ────────────────────────────────────────────────────────────────
do_snapshot() {
  head "🧠 Claude Code memory → $(tilde "$SNAPSHOT")"
  if [[ ! -d "$PRIVATE_REPO/.git" ]]; then
    bad "no private repo at $(tilde "$PRIVATE_REPO"). Run 'make private-init'"
    exit 1
  fi
  local repo mem dest copied=0
  for repo in "${REPOS[@]}"; do
    mem="$(memory_of "$repo")"
    has_memory "$mem" || continue
    dest="$SNAPSHOT/$(slug "$repo")/memory"
    if diff -rq "$mem" "$dest" >/dev/null 2>&1; then
      ok "$(tilde "$repo") unchanged"
      continue
    fi
    mkdir -p "$dest"
    rsync -a --delete "$mem/" "$dest/"
    ok "copied $(tilde "$repo")"
    copied=$((copied + 1))
  done
  ((copied)) && info "run 'make private-push' to commit and push it"
  exit 0
}

case "${1:-}" in
  check) do_check ;;
  snapshot) do_snapshot ;;
  -h|--help) sed -n '2,/^####/p' "$0" | sed 's/^# \{0,1\}//; /^#*$/d'; exit 0 ;;
  *) printf "usage: %s check|snapshot\n" "$(basename "$0")" >&2; exit 2 ;;
esac
