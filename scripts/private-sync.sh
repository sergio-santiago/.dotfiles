#!/bin/bash
################################################################################
# Private config sync
#
# Description:
#   Copies the few machine-private files this setup needs between $HOME and a
#   separate PRIVATE git repo (~/.dotfiles-private by default). They cannot live in
#   this repo because this one is public: ~/.ssh/config.private names ten hosts with
#   the user to log in as, and ~/.aws/config names the account ids and roles behind
#   six SSO profiles. Neither is a credential, the keys that grant access are in
#   1Password. Both are a target list, which is worth not publishing, and if the
#   hosts belong to a client it is their confidentiality and not only yours.
#
#   Plaintext in a private repo rather than ciphertext here, on purpose. Encrypting
#   would mean a passphrase you can never lose and diffs you cannot read, and git
#   keeps every old ciphertext forever, so rotating that passphrase would not
#   protect the versions already pushed. For a target list with no credentials in
#   it, that trade does not pay.
#
#   Every copy into the private repo is screened first, because the ceiling of
#   these files is far above their current contents. ssh_config accepts
#   ProxyCommand, which is exactly where people embed tokens, and its comments are
#   a note-taking surface. A file that trips the screen is never copied.
#
#   The remote is never created and never pushed to without you asking: `init`
#   stops at a local repo and prints the two commands, because publishing a host
#   list is the one step here that cannot be undone.
#
# Usage:
#   ./scripts/private-sync.sh [status|push|pull|scan|init] [--dry-run]
#
#   status   what differs between $HOME and the private repo (the default)
#   push     $HOME → private repo, screened, committed, pushed if a remote exists
#   pull     private repo → $HOME, backing up anything in the way first
#   scan     run the screen over the $HOME copies and report, changing nothing
#   init     create the local private repo, no remote, no push
#
#   Override the location with DOTFILES_PRIVATE=/some/path.
################################################################################

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIVATE_REPO="${DOTFILES_PRIVATE:-$HOME/.dotfiles-private}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# shellcheck source=./private-files.sh
source "$DOTFILES/scripts/private-files.sh"

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
bad()  { printf "  %s✗%s %s\n" "$RED" "$RESET" "$1"; }
head() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }
plan() { printf "  %s→ would %s%s\n" "$DIM" "$1" "$RESET"; }

tilde() { printf '%s' "${1/#$HOME/~}"; }

# ── Arguments ───────────────────────────────────────────────────────────────
DRY=0
CMD=""

usage() {
  cat <<EOF
${BOLD}private-sync.sh${RESET} - sync machine-private config with a separate private repo

  status          what differs between \$HOME and the private repo (default)
  push            \$HOME → private repo: screen, copy, commit, push if a remote exists
  pull            private repo → \$HOME, backing up anything in the way
  scan            run the secret screen over the \$HOME copies, change nothing
  init            create the local private repo (no remote, no push)

  -n, --dry-run   print what would happen and change nothing
  -h, --help      this text

Location: ${PRIVATE_REPO/#$HOME/~} (override with DOTFILES_PRIVATE)
Which files: scripts/private-files.sh
EOF
}

while (($#)); do
  case "$1" in
    status|push|pull|scan|init)
      [[ -n "$CMD" ]] && { printf "give one command, not two: %s and %s\n\n" "$CMD" "$1" >&2; usage >&2; exit 2; }
      CMD="$1" ;;
    -n|--dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf "unknown option: %s\n\n" "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
CMD="${CMD:-status}"

# ── The secret screen ───────────────────────────────────────────────────────
# Format "<what it is>::<regex>". Two colons rather than a pipe because several of
# these regexes would need alternation and the map format already spends the pipe.
# None of them contains one, so splitting is unambiguous.
#
# The word-based patterns require an = or : before the value, which is what keeps
# ssh_config's own `PasswordAuthentication no` from tripping them: ssh separates a
# keyword from its value with a space.
SECRET_PATTERNS=(
  "an OpenSSH or PEM private key block::BEGIN [A-Z ]*PRIVATE KEY"
  "an AWS access key id::AKIA[0-9A-Z]{16}"
  "a long-lived AWS secret key::aws_secret_access_key"
  "an AWS session token::aws_session_token"
  "a GitHub token::gh[pousr]_[A-Za-z0-9]{16,}"
  "a GitHub fine-grained token::github_pat_[A-Za-z0-9_]{20,}"
  "a Slack token::xox[abeprs]-[A-Za-z0-9-]{10,}"
  "an OpenAI or Anthropic style key::sk-[A-Za-z0-9_-]{20,}"
  "an assigned password::[Pp]assword[[:space:]]*[=:][[:space:]]*[^[:space:]]{6,}"
  "an assigned passphrase::[Pp]assphrase[[:space:]]*[=:][[:space:]]*[^[:space:]]{6,}"
  "an assigned secret::[Ss]ecret[[:space:]]*[=:][[:space:]]*[^[:space:]]{6,}"
)

# 0 clean, 1 tripped. Reports the line numbers and what matched by name, and never
# the matched text itself: a screen that echoes the secret it caught has just
# copied it into your scrollback, your terminal log and this script's output.
scan_file() { # path
  local path=$1 entry name regex lines rc=0
  for entry in "${SECRET_PATTERNS[@]}"; do
    name="${entry%%::*}"
    regex="${entry#*::}"
    lines="$(grep -nE "$regex" "$path" 2>/dev/null | cut -d: -f1 | tr '\n' ' ' || true)"
    lines="${lines% }"
    if [[ -n "$lines" ]]; then
      bad "$(tilde "$path") looks like it holds $name, on line(s) $lines"
      rc=1
    fi
  done
  return $rc
}

# ── Reading the map ─────────────────────────────────────────────────────────
# Split once, here, so the four commands below cannot disagree about the format.
src_of()  { printf '%s' "${1%%|*}"; }
dest_of() { printf '%s' "$PRIVATE_REPO/${1#*|}"; }

require_repo() {
  if [[ ! -d "$PRIVATE_REPO/.git" ]]; then
    bad "no private repo at $(tilde "$PRIVATE_REPO")"
    info "create it with 'make private-init'"
    exit 1
  fi
}

# ── init ────────────────────────────────────────────────────────────────────
do_init() {
  head "🔐 Private repo"

  if [[ -d "$PRIVATE_REPO/.git" ]]; then
    ok "already a git repo at $(tilde "$PRIVATE_REPO")"
    return 0
  fi

  if ((DRY)); then
    plan "create $(tilde "$PRIVATE_REPO") with mode 0700"
    plan "run git init -b main in it"
    plan "write its README.md and .gitignore"
    plan "create no remote and push nothing"
    return 0
  fi

  # 0700 from the moment it exists rather than chmod'ed afterwards, so there is no
  # window where a world-readable directory holds the host list.
  mkdir -p -m 700 "$PRIVATE_REPO"
  chmod 700 "$PRIVATE_REPO"
  ok "created $(tilde "$PRIVATE_REPO") (0700)"

  git -C "$PRIVATE_REPO" init -b main >/dev/null 2>&1 || git -C "$PRIVATE_REPO" init >/dev/null
  ok "git init"

  # Second layer, independent of the screen in this script. The screen inspects
  # contents, this refuses whole filenames that should never be here at all, so a
  # file added by hand rather than through the map is still caught.
  cat >"$PRIVATE_REPO/.gitignore" <<'EOF'
# Files that must never be committed here, whatever the reason seemed to be.
# The map in ~/.dotfiles/scripts/private-files.sh decides what belongs. This is the
# backstop for anything added by hand.
credentials
*.pem
*.key
*.p12
*.keychain
id_rsa
id_ecdsa
id_ed25519
.env
.env.*
*.secrets
*.token
.DS_Store
EOF

  cat >"$PRIVATE_REPO/README.md" <<'EOF'
# .dotfiles-private

The private half of [`.dotfiles`](https://github.com/sergio-santiago/.dotfiles).
**Keep this repo private.**

Nothing here is a credential. It is machine-private configuration, SSH host
aliases and AWS SSO profiles, which is a target list rather than a way in. The
keys and tokens that actually grant access live in 1Password and are synced by
nothing.

## These files are copies, do not edit them here

The live files are the ones in `$HOME`. Edit `~/.ssh/config.private` the way you
always did, then push. A change made to the copy in this repo is silently
overwritten by the next `private-push`.

## Nothing syncs by itself

There is no hook, no daemon and no scheduled job. Everything is driven from the
public repo, by hand:

```sh
make private-status   # what differs, and whether anything left this machine
make private-push     # $HOME → here: screen, copy, commit, push
make private-pull     # here → $HOME, backing up anything in the way first
make private-scan     # run the secret screen alone, change nothing
```

`make doctor` is what tells you this repo has fallen behind, so you do not have
to remember.

## On a new machine

```sh
git clone git@github.com:sergio-santiago/dotfiles-private.git ~/.dotfiles-private
make private-pull
```

`private-pull` sets the restored files to 0600. Git records only the executable
bit, so the modes stored here read as 644 and mean nothing.

## What gets synced, and the screen

`~/.dotfiles/scripts/private-files.sh` decides, as an explicit list of files and
never a directory: `~/.aws/config` is safe to sync and `~/.aws/credentials`,
which one `aws configure` writes beside it, is not.

`private-push` screens every file for credential-shaped content first. One hit
refuses the entire run, including the files that passed, and the report gives
line numbers without ever printing what it matched.
EOF
  ok "wrote README.md and .gitignore"

  head "Next, and only if you want a remote"
  info "the host list is not published until you run these:"
  printf "\n    gh repo create dotfiles-private --private --source %s --remote origin\n" "$(tilde "$PRIVATE_REPO")"
  printf "    make private-push\n\n"
  info "verify it is private first: gh repo view dotfiles-private --json isPrivate"
}

# ── scan ────────────────────────────────────────────────────────────────────
do_scan() {
  head "🔍 Secret screen"
  local entry src found=0 checked=0
  for entry in "${PRIVATE_FILES[@]}"; do
    src="$(src_of "$entry")"
    if [[ ! -f "$src" ]]; then
      warn "$(tilde "$src") does not exist here, nothing to screen"
      continue
    fi
    checked=$((checked + 1))
    if scan_file "$src"; then
      ok "$(tilde "$src") is clean"
    else
      found=$((found + 1))
    fi
  done
  if ((found)); then
    warn "$found file(s) tripped the screen. Move the secret into 1Password and re-run"
    return 1
  fi
  ((checked)) && ok "all $checked file(s) clean"
  return 0
}

# ── status ──────────────────────────────────────────────────────────────────
do_status() {
  head "🔐 Private config"
  info "repo: $(tilde "$PRIVATE_REPO")"

  if [[ ! -d "$PRIVATE_REPO/.git" ]]; then
    warn "not set up. Run 'make private-init'"
    return 0
  fi

  local entry src dest differs=0
  for entry in "${PRIVATE_FILES[@]}"; do
    src="$(src_of "$entry")"; dest="$(dest_of "$entry")"
    if [[ ! -f "$src" && ! -f "$dest" ]]; then
      warn "$(tilde "$src") exists in neither place"
    elif [[ ! -f "$dest" ]]; then
      warn "$(tilde "$src") has never been pushed"; differs=$((differs + 1))
    elif [[ ! -f "$src" ]]; then
      warn "$(tilde "$src") is missing here but is in the repo. 'make private-pull' restores it"
      differs=$((differs + 1))
    elif cmp -s "$src" "$dest"; then
      ok "$(tilde "$src") is in sync"
    else
      warn "$(tilde "$src") differs from the pushed copy"; differs=$((differs + 1))
    fi
  done

  # Uncommitted or unpushed work in the private repo is its own kind of drift: the
  # files can match perfectly while nothing has left this machine.
  if [[ -n "$(git -C "$PRIVATE_REPO" status --porcelain 2>/dev/null)" ]]; then
    warn "the private repo has uncommitted changes"
  elif ! git -C "$PRIVATE_REPO" remote get-url origin >/dev/null 2>&1; then
    warn "the private repo has no remote, so nothing is backed up off this machine"
  else
    local ahead
    ahead="$(git -C "$PRIVATE_REPO" rev-list --count @{u}..HEAD 2>/dev/null || echo "?")"
    if [[ "$ahead" == "?" ]]; then
      warn "the private repo has a remote but no upstream branch yet. Run 'make private-push'"
    elif [[ "$ahead" == "0" ]]; then
      ok "the private repo is committed and pushed"
    else
      warn "the private repo is $ahead commit(s) ahead of its remote"
    fi
  fi

  ((differs)) && info "run 'make private-push' to update the repo from \$HOME"
  return 0
}

# ── push ────────────────────────────────────────────────────────────────────
do_push() {
  require_repo
  head "🔍 Secret screen"

  # Screened as one batch before anything is copied. A per-file screen that copied
  # as it went would leave the clean half staged next to a refused run, and the
  # next push would carry it without ever having said so.
  local entry src dest tripped=0
  for entry in "${PRIVATE_FILES[@]}"; do
    src="$(src_of "$entry")"
    [[ -f "$src" ]] || continue
    if scan_file "$src"; then ok "$(tilde "$src") is clean"; else tripped=$((tripped + 1)); fi
  done
  if ((tripped)); then
    bad "refusing to copy anything: $tripped file(s) tripped the screen"
    info "move the secret into 1Password, then re-run"
    exit 1
  fi

  head "📤 Copying into the private repo"
  local copied=0
  for entry in "${PRIVATE_FILES[@]}"; do
    src="$(src_of "$entry")"; dest="$(dest_of "$entry")"
    if [[ ! -f "$src" ]]; then
      warn "$(tilde "$src") does not exist here, skipping"
      continue
    fi
    if cmp -s "$src" "$dest" 2>/dev/null; then
      ok "$(tilde "$src") unchanged"
      continue
    fi
    if ((DRY)); then
      plan "copy $(tilde "$src") → $(tilde "$dest") (0600)"
      copied=$((copied + 1))
      continue
    fi
    mkdir -p -m 700 "$(dirname "$dest")"
    cp "$src" "$dest"
    # chmod and not just umask. umask applies when a file is created, and cp onto an
    # existing destination keeps whatever mode that file already had, so a copy
    # written once at 0644 would stay 0644 through every later push.
    chmod 600 "$dest"
    ok "copied $(tilde "$src")"
    copied=$((copied + 1))
  done

  head "📦 Commit"
  if ((DRY)); then
    if ((copied)); then
      plan "commit $copied change(s) as 'chore: sync private config'"
      if git -C "$PRIVATE_REPO" remote get-url origin >/dev/null 2>&1; then
        plan "push to origin"
      else
        plan "stop here, since there is no remote"
      fi
    else
      info "nothing to commit"
    fi
    return 0
  fi

  if [[ -z "$(git -C "$PRIVATE_REPO" status --porcelain)" ]]; then
    ok "nothing changed, no commit needed"
  else
    git -C "$PRIVATE_REPO" add -A
    git -C "$PRIVATE_REPO" commit -q -m "chore: sync private config"
    ok "committed"
  fi

  if git -C "$PRIVATE_REPO" remote get-url origin >/dev/null 2>&1; then
    local branch
    branch="$(git -C "$PRIVATE_REPO" rev-parse --abbrev-ref HEAD)"
    if git -C "$PRIVATE_REPO" push -u origin "$branch" >/dev/null 2>&1; then
      ok "pushed to origin/$branch"
    else
      warn "push failed. Run 'git -C $(tilde "$PRIVATE_REPO") push -u origin $branch' to see why"
    fi
  else
    warn "no remote, so this is committed locally and nowhere else"
    info "add one: gh repo create dotfiles-private --private --source $(tilde "$PRIVATE_REPO") --remote origin"
  fi
}

# ── pull ────────────────────────────────────────────────────────────────────
do_pull() {
  require_repo
  head "📥 Restoring into \$HOME"
  info "backup: $(tilde "$BACKUP_DIR") ${DIM}(only created if needed)${RESET}"

  local entry src dest
  for entry in "${PRIVATE_FILES[@]}"; do
    src="$(src_of "$entry")"; dest="$(dest_of "$entry")"
    if [[ ! -f "$dest" ]]; then
      warn "$(tilde "$dest") is not in the repo, nothing to restore"
      continue
    fi
    if cmp -s "$src" "$dest" 2>/dev/null; then
      ok "$(tilde "$src") already matches"
      continue
    fi
    # Anything already there is moved aside, never overwritten, matching what
    # install.sh does. This direction writes to $HOME, so it is the one that can
    # cost you a file you meant to keep.
    if [[ -f "$src" ]]; then
      if ((DRY)); then
        plan "back up $(tilde "$src") → $(tilde "$BACKUP_DIR$src")"
      else
        mkdir -p -m 700 "$(dirname "$BACKUP_DIR$src")"
        cp "$src" "$BACKUP_DIR$src"
        warn "backed up $(tilde "$src")"
      fi
    fi
    if ((DRY)); then
      plan "restore $(tilde "$dest") → $(tilde "$src") (0600)"
      continue
    fi
    mkdir -p -m 700 "$(dirname "$src")"
    cp "$dest" "$src"
    chmod 600 "$src"
    ok "restored $(tilde "$src")"
  done
}

# ── Run ─────────────────────────────────────────────────────────────────────
if ((DRY)); then
  printf "\n%s%sDry run%s: nothing below is performed.\n" "$BOLD" "$YELLOW" "$RESET"
fi

case "$CMD" in
  init)   do_init ;;
  scan)   do_scan ;;
  status) do_status ;;
  push)   do_push ;;
  pull)   do_pull ;;
esac
