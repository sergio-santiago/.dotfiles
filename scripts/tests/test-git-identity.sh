#!/usr/bin/env bash
################################################################################
# Tests for the git identity map
#
# Which address a commit is authored with is decided by git/config and the
# git/config-* files it pulls in, and the README restates that map in a table.
# Two copies of the same fact, so this compares them.
#
# It is worth pinning because getting it wrong is silent and permanent. GitHub
# links a commit to an account by matching the author address against the
# addresses on it, so a repository that quietly picks up the wrong identity ends
# up with commits that stop counting the day that address leaves the account.
# There is no error at commit time and nothing to notice afterwards.
#
# The README is allowed to mask the local part of the personal address, so the
# comparison is on the domain.
################################################################################

GITCFG="$DOTFILES/git/config"
GITREADME="$DOTFILES/README.md"

# Every includeIf and the file it pulls in, as "gitdir|path" pairs. The paths are
# written with a leading ~ because git expands them itself, so they are mapped
# back onto this checkout rather than onto whatever $HOME happens to be.
include_pairs() {
  awk '
    /^\[includeIf "gitdir:/ {
      line = $0
      sub(/^\[includeIf "gitdir:/, "", line)
      sub(/"\]$/, "", line)
      dir = line
      next
    }
    dir != "" && /^[[:space:]]*path[[:space:]]*=/ {
      p = $0
      sub(/^[[:space:]]*path[[:space:]]*=[[:space:]]*/, "", p)
      print dir "|" p
      dir = ""
    }
  ' "$GITCFG"
}

resolve() { # ~/.dotfiles/git/config-x -> this checkout
  printf '%s' "${1/#\~\/.dotfiles/$DOTFILES}"
}

email_in() { # path to an identity file
  grep -oE '^[[:space:]]*email[[:space:]]*=[[:space:]]*\S+' "$1" | sed 's/.*=[[:space:]]*//'
}

domain_of() { printf '%s' "${1#*@}"; }

# ── Every includeIf points at a file that is actually there ─────────────────
# A typo here does not fail, it just silently applies nothing, which is the
# whole failure mode this test exists for.
MISSING=""
while IFS='|' read -r dir path; do
  [[ -n "$dir" ]] || continue
  [[ -f "$(resolve "$path")" ]] || MISSING+="$dir -> $path "
done < <(include_pairs)

it "every includeIf in git/config points at an identity file that exists"
assert_eq "" "$MISSING"

# ── No identity file is left orphaned ───────────────────────────────────────
ORPHANS=""
for f in "$DOTFILES"/git/config-*; do
  [[ -f "$f" ]] || continue
  include_pairs | grep -q "|.*$(basename "$f")\$" || ORPHANS+="$(basename "$f") "
done

it "every git/config-* file is pulled in by at least one includeIf"
assert_eq "" "$ORPHANS"

# ── The README names the same identity files the config does ────────────────
CONFIG_FILES="$(include_pairs | sed 's|.*/||' | sort -u)"
README_FILES="$(grep -oE 'git/config-[a-z]+' "$GITREADME" | sed 's|git/||' | sort -u)"

it "the README's identity table names exactly the identity files in use"
assert_eq "$CONFIG_FILES" "$README_FILES"

# ── Each address in the README matches the file it claims to describe ───────
# Row shape: | <locations> | `git/config-x` | `someone@domain` |
MISMATCHED=""
while IFS= read -r row; do
  file="$(printf '%s' "$row" | grep -oE 'git/config-[a-z]+' | head -1)"
  claimed="$(printf '%s' "$row" | grep -oE '`[^`]*@[^`]+`' | tail -1 | tr -d '`')"
  [[ -n "$file" && -n "$claimed" ]] || continue
  actual="$(email_in "$DOTFILES/$file")"
  [[ "$(domain_of "$claimed")" == "$(domain_of "$actual")" ]] \
    || MISMATCHED+="$file: README says $claimed, file says $actual "
done < <(grep -E '^\| .*`git/config-[a-z]+`' "$GITREADME")

it "every address in the README matches the identity file it points at"
assert_eq "" "$MISMATCHED"

# ── The default is the personal address, not a work one ─────────────────────
# The direction of this is the point, not the value. Defaulting to a work
# address is what put the wrong author on hundreds of public personal commits,
# because anything cloned outside a listed directory inherits the default.
DEFAULT_EMAIL="$(awk '/^\[user\]/{u=1;next} /^\[/{u=0} u && /^[[:space:]]*email[[:space:]]*=/{sub(/.*=[[:space:]]*/,"");print;exit}' "$GITCFG")"
PERSONAL_EMAIL="$(email_in "$DOTFILES/git/config-personal")"

it "git/config defaults to the personal address, so a stray clone cannot inherit a work one"
assert_eq "$PERSONAL_EMAIL" "$DEFAULT_EMAIL"

# ── The repositories that live outside ~/Projects are covered explicitly ────
# These two are personal, public and not under ~/Projects, which is exactly the
# gap the old config had.
UNCOVERED=""
for repo in '~/.dotfiles/' '~/.dotfiles-private/'; do
  include_pairs | grep -q "^$repo|" || UNCOVERED+="$repo "
done

it "~/.dotfiles and ~/.dotfiles-private have an identity rule of their own"
assert_eq "" "$UNCOVERED"
