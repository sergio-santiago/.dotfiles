#!/usr/bin/env bash
################################################################################
# Tests for scripts/install.sh
#
# Every case runs against a throwaway HOME, so the real one is never touched. The
# repo itself is the source of the links either way: what is under test is what the
# installer does to $HOME, not what it reads.
#
# The property worth pinning down is the pair. `--dry-run` has to describe exactly
# the run that `make link` then performs, and it has to leave nothing behind. A dry
# run that quietly created a directory would be worse than no dry run at all,
# because it would be trusted.
################################################################################

INSTALL="$DOTFILES/scripts/install.sh"

# The expected link count comes from the map itself, not from a literal. Hardcoded,
# adding a legitimate symlink failed these tests for the wrong reason and the failure
# said nothing about what had actually changed.
# shellcheck source=../links.sh
source "$DOTFILES/scripts/links.sh"
LINK_COUNT=${#LINKS[@]}

# A fresh HOME per case. XDG_CACHE_HOME travels with it so `bat cache --build`
# cannot reach the real cache.
fresh_home() {
  CASE_HOME="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  export CASE_HOME
}

install_run() { # [flags...]
  OUT="$(env HOME="$CASE_HOME" XDG_CACHE_HOME="$CASE_HOME/.cache" \
    bash "$INSTALL" "$@" 2>&1)"
  RC=$?
}

# Everything the installer put in $HOME, as repo-relative-ish paths, sorted. Used to
# compare a dry run's plan against the real run's result.
links_made() {
  (cd "$CASE_HOME" && find . -type l 2>/dev/null | sed 's|^\./||' | sort)
}

# ── A dry run changes nothing at all ────────────────────────────────────────
fresh_home
install_run --dry-run

it "--dry-run exits 0"
assert_eq 0 "$RC"

it "--dry-run says so, so its output cannot be mistaken for a real run"
assert_contains "$OUT" "Dry run"

it "--dry-run creates no symlink"
assert_eq "" "$(links_made | tr '\n' ' ')"

it "--dry-run creates no file or directory whatsoever"
assert_eq "" "$(find "$CASE_HOME" -mindepth 1 2>/dev/null | tr '\n' ' ')"

it "--dry-run does not create the private SSH config it would otherwise write"
assert_no_file "$CASE_HOME/.ssh/config.private"

it "--dry-run announces the links in the future tense"
assert_contains "$OUT" "would link"

it "--dry-run announces the mode it would enforce on ~/.ssh"
assert_contains "$OUT" "0700"

# Each parent is announced once. Nothing is created, so the "does it exist" test
# stays false and a naive implementation repeated ~/.claude for every entry under it.
it "--dry-run announces each parent directory only once"
assert_eq 1 "$(printf '%s\n' "$OUT" | grep -c 'would create ~/.claude$')"

# ~/.ssh is reached twice, once by link_one for ssh/config and once by the private
# config section, and a dry run creates nothing so both tests stayed true.
it "--dry-run announces ~/.ssh once, not once per section that would create it"
assert_eq 1 "$(printf '%s\n' "$OUT" | grep -c 'would create ~/\.ssh$')"

# ── -n is the same flag ─────────────────────────────────────────────────────
fresh_home
install_run -n
it "-n is accepted as the short form"
assert_contains "$OUT" "Dry run"

it "-n leaves the HOME untouched too"
assert_eq "" "$(find "$CASE_HOME" -mindepth 1 2>/dev/null | tr '\n' ' ')"

# ── The plan matches what a real run then does ──────────────────────────────
# Two HOMEs in the same starting state: one planned, one performed. Every
# destination the plan named has to be a symlink afterwards, and no others.
fresh_home
install_run --dry-run
PLANNED="$(printf '%s\n' "$OUT" | sed -nE 's|^ *→ would link ~/([^ ]+) → .*|\1|p' | sort)"

fresh_home
install_run
ACTUAL="$(links_made)"

it "a real run exits 0"
assert_eq 0 "$RC"

it "the plan named exactly the links the real run created"
assert_eq "$(printf '%s\n' "$PLANNED" | tr '\n' ' ')" "$(printf '%s\n' "$ACTUAL" | tr '\n' ' ')"

it "the plan is not empty, so the comparison above proves something"
assert_eq "$LINK_COUNT" "$(printf '%s\n' "$PLANNED" | grep -c .)"

# ── The real run's promises ─────────────────────────────────────────────────
it "a real run creates the private SSH config"
assert_file "$CASE_HOME/.ssh/config.private"

it "~/.ssh is 0700, since the directory lists your private hostnames"
assert_eq 700 "$(stat -f '%Lp' "$CASE_HOME/.ssh" 2>/dev/null)"

it "~/.ssh/config.private is 0600"
assert_eq 600 "$(stat -f '%Lp' "$CASE_HOME/.ssh/config.private" 2>/dev/null)"

it "no link is left dangling"
assert_eq "" "$(find "$CASE_HOME" -type l ! -exec test -e {} \; -print 2>/dev/null | tr '\n' ' ')"

# ── Re-running is safe and quiet ────────────────────────────────────────────
install_run
it "a second run exits 0"
assert_eq 0 "$RC"

it "a second run recognises every link as already correct"
assert_eq "$LINK_COUNT" "$(printf '%s\n' "$OUT" | grep -c 'already linked')"

it "a second run backs nothing up, because there was nothing in the way"
assert_not_contains "$OUT" "backed up"

# ── Anything in the way is moved aside, never overwritten ───────────────────
fresh_home
mkdir -p "$CASE_HOME/.config"
printf 'the starship config I had before\n' >"$CASE_HOME/.config/starship.toml"
install_run

it "an existing file is backed up rather than clobbered"
assert_contains "$OUT" "backed up"

it "the backup keeps the original contents byte for byte"
assert_eq "the starship config I had before" \
  "$(find "$CASE_HOME/.dotfiles-backup" -name starship.toml -exec cat {} \; 2>/dev/null)"

it "and the destination is a symlink afterwards"
assert_eq 0 "$([[ -L "$CASE_HOME/.config/starship.toml" ]] && echo 0 || echo 1)"

# The same file, announced and left alone. This is the case where a dry run that
# lied would cost you a config you meant to keep.
fresh_home
mkdir -p "$CASE_HOME/.config"
printf 'the starship config I had before\n' >"$CASE_HOME/.config/starship.toml"
install_run --dry-run

it "--dry-run announces the backup it would take"
assert_contains "$OUT" "would back up"

it "--dry-run leaves the file it would have moved exactly where it was"
assert_eq "the starship config I had before" "$(cat "$CASE_HOME/.config/starship.toml")"

it "--dry-run creates no backup directory"
assert_no_file "$CASE_HOME/.dotfiles-backup"

# ── Argument handling matches brew-maintenance's contract ───────────────────
fresh_home
install_run --help
it "--help exits 0"
assert_eq 0 "$RC"

it "--help documents the dry run"
assert_contains "$OUT" "--dry-run"

it "--help creates nothing"
assert_eq "" "$(find "$CASE_HOME" -mindepth 1 2>/dev/null | tr '\n' ' ')"

fresh_home
install_run --nope
it "an unknown flag exits 2, distinct from a failed run"
assert_eq 2 "$RC"

it "an unknown flag changes nothing before rejecting the run"
assert_eq "" "$(find "$CASE_HOME" -mindepth 1 2>/dev/null | tr '\n' ' ')"

# ── The README's manual instructions describe the same map ──────────────────
# The "Prefer to link manually?" block in the README is a hand-written copy of
# scripts/links.sh, and a copy drifts. Someone following stale instructions ends up
# with a machine missing exactly the links that were added after the block was
# written, and nothing tells them. Compared as source→destination pairs, so a typo
# in either half fails rather than a mere count matching by luck.
# A % delimiter throughout: the map's own separator is |, and using that as the sed
# delimiter matched the header comment as well and silently inflated the count to 23.
map_from_links() {
  sed -nE 's%^[[:space:]]*"([^|]+)[|]([^"]+)".*%\1 \2%p' "$DOTFILES/scripts/links.sh" |
    sed 's%\$HOME%~%' | sort
}
map_from_readme() {
  sed -nE 's%^ln -sfh ~/\.dotfiles/([^ ]+) ([^ ]+)$%\1 \2%p' "$DOTFILES/README.md" | sort
}

# Reported as the difference alone. Comparing the two lists whole made a one-entry
# drift print forty lines, which is the kind of failure people stop reading.
MAP_DIFF="$(comm -3 <(map_from_links) <(map_from_readme) | tr '\t' ' ' | tr '\n' '·')"
it "the README's manual ln commands cover every link in links.sh, and no others"
assert_eq "" "${MAP_DIFF}"

it "the map is not empty, so the comparison above proves something"
assert_eq "$LINK_COUNT" "$(map_from_links | grep -c .)"

unset CASE_HOME
