#!/usr/bin/env bash
################################################################################
# Tests for scripts/backup-check.sh
#
# Every case builds a throwaway HOME holding a copy of this repo's two scripts, a
# private repo and a personal repo, each with a bare remote it has been pushed to.
# The real ~/.dotfiles, ~/.claude and ~/Library/LaunchAgents are never read.
#
# The property that carries the weight is the exit code. A check that passes while
# something is still only on the disk is worse than no check, because it is the
# thing you trust when the disk is about to go. So every way of failing is tested on
# its own, against a baseline that passes.
################################################################################

# A git identity in the environment: HOME is redirected, so git would find no
# user.name and every commit here would fail for an unrelated reason.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid \
       GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

# init + one commit + a bare remote it is pushed to. The remotes live apart, or the
# glob in the repo list would pick them up as repos of their own.
pushed_repo() { # path
  local remote; remote="$CASE_HOME/remotes/$(slug "$1").git"
  git init -q -b main "$1"
  printf 'x\n' >"$1/file"
  git -C "$1" add file && git -C "$1" commit -q -m init
  git init -q --bare "$remote"
  git -C "$1" remote add origin "$remote"
  git -C "$1" push -q -u origin main
}

slug() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

fresh_backup_home() {
  CASE_HOME="$(cd "$(mktemp -d "$SCRATCH/backup.XXXXXX")" && pwd -P)"
  RDOT="$CASE_HOME/.dotfiles"; RPRIV="$CASE_HOME/.dotfiles-private"
  RPROJ="$CASE_HOME/Projects/personal/one"
  pushed_repo "$RDOT"
  mkdir -p "$RDOT/scripts"
  cp "$DOTFILES/scripts/backup-check.sh" "$DOTFILES/scripts/private-files.sh" "$RDOT/scripts/"
  git -C "$RDOT" add scripts && git -C "$RDOT" commit -q -m scripts && git -C "$RDOT" push -q
  pushed_repo "$RPRIV"
  mkdir -p "$(dirname "$RPROJ")" "$CASE_HOME/.config/backup-check"
  pushed_repo "$RPROJ"
  printf '# personal\n~/Projects/personal/*\n' >"$CASE_HOME/.config/backup-check/repos"
  # The list is itself a mapped private file, so a passing baseline has it pushed.
  mkdir -p "$RPRIV/backup-check" && cp "$CASE_HOME/.config/backup-check/repos" "$RPRIV/backup-check/"
  git -C "$RPRIV" add -A && git -C "$RPRIV" commit -q -m list && git -C "$RPRIV" push -q
}

backup_run() { # check|snapshot
  OUT="$(env HOME="$CASE_HOME" bash "$RDOT/scripts/backup-check.sh" "$@" 2>&1)"
  RC=$?
}

# A memory folder for the personal repo, with a snapshot that matches it
with_memory() {
  local mem; mem="$CASE_HOME/.claude/projects/$(slug "$RPROJ")/memory"
  mkdir -p "$mem" && printf 'a fact\n' >"$mem/fact.md"
  backup_run snapshot
  git -C "$RPRIV" add -A && git -C "$RPRIV" commit -q -m snapshot && git -C "$RPRIV" push -q
}

agent() { # label program [arg]
  mkdir -p "$CASE_HOME/Library/LaunchAgents"
  local args="<string>$2</string>"; [[ -n "${3:-}" ]] && args+="<string>$3</string>"
  cat >"$CASE_HOME/Library/LaunchAgents/$1.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>$1</string>
<key>ProgramArguments</key><array>$args</array></dict></plist>
EOF
}

# ── The baseline passes ─────────────────────────────────────────────────────
fresh_backup_home; with_memory; backup_run check
it "a machine with everything pushed and snapshotted passes"
assert_eq "0" "$RC"
it "and it says so"
assert_contains "$OUT" "nothing found that lives only on this disk"
it "it checks the repos in the private list, globs included"
assert_contains "$OUT" "~/Projects/personal/one"

# ── Each way of failing, on its own ─────────────────────────────────────────
fresh_backup_home; printf 'y\n' >"$RPROJ/file"; backup_run check
it "an uncommitted change fails the check"
assert_eq "1" "$RC"
it "and names the repo and the count"
assert_contains "$OUT" "~/Projects/personal/one: 1 uncommitted change(s)"

fresh_backup_home; printf 'y\n' >"$RPROJ/file"; git -C "$RPROJ" commit -qam local; backup_run check
it "a commit on no remote fails the check"
assert_contains "$OUT" "1 commit(s) on no remote"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; git -C "$RPROJ" switch -q -c side; printf 'y\n' >"$RPROJ/file"
git -C "$RPROJ" commit -qam branch; git -C "$RPROJ" switch -q main; backup_run check
it "a commit on a local branch other than the current one counts too"
assert_contains "$OUT" "1 commit(s) on no remote"

fresh_backup_home; printf 'y\n' >"$RPROJ/file"; git -C "$RPROJ" stash -q; backup_run check
it "a stash fails the check, since it is on no remote either"
assert_contains "$OUT" "1 stash(es)"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; git -C "$RPROJ" remote remove origin; backup_run check
it "a repo with no remote fails the check"
assert_contains "$OUT" "no remote"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; mkdir -p "$CASE_HOME/Projects/personal/plain"; backup_run check
it "a listed folder that is not a git repo fails, since nothing in it is backed up"
assert_contains "$OUT" "is not a git repository"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; with_memory; printf 'another\n' >>"$CASE_HOME/.claude/projects/$(slug "$RPROJ")/memory/fact.md"
backup_run check
it "memory that changed after the snapshot fails the check"
assert_contains "$OUT" "memory differs from its snapshot"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; mkdir -p "$CASE_HOME/.claude/projects/$(slug "$RPROJ")/memory"
printf 'a fact\n' >"$CASE_HOME/.claude/projects/$(slug "$RPROJ")/memory/fact.md"; backup_run check
it "memory that was never snapshotted fails the check"
assert_contains "$OUT" "has memory with no snapshot"

fresh_backup_home; with_memory; backup_run snapshot
it "a snapshot with nothing new copies nothing"
assert_contains "$OUT" "unchanged"
it "and leaves the private repo clean"
assert_eq "" "$(git -C "$RPRIV" status --porcelain)"

fresh_backup_home
mkdir -p "$CASE_HOME/.config/finicky"; printf 'export default {}\n' >"$CASE_HOME/.config/finicky/finicky.ts"
backup_run check
it "a mapped private file that is not in the private repo fails the check"
assert_contains "$OUT" "finicky.ts differs from the private repo"
it "  and exits 1"
assert_eq "1" "$RC"

fresh_backup_home; printf 'z\n' >"$RPRIV/new"; git -C "$RPRIV" add new; git -C "$RPRIV" commit -qm local
backup_run check
it "a private repo with an unpushed commit fails the check"
assert_contains "$OUT" "the private repo has commits on no remote"
it "  and exits 1"
assert_eq "1" "$RC"

# ── launchd agents warn, they do not fail ───────────────────────────────────
fresh_backup_home; agent mine /usr/bin/python3 "$CASE_HOME/Library/Application Support/mine/run.py"
agent vendor "$CASE_HOME/Library/Application Support/Vendor/Updater.app/Contents/MacOS/Updater"
agent system /usr/bin/true
backup_run check
it "an agent running a script under HOME through /usr/bin is reported"
assert_contains "$OUT" "mine runs ~/Library/Application Support/mine/run.py"
it "an agent inside an installed .app is not"
assert_not_contains "$OUT" "vendor runs"
it "nor one that runs only system binaries"
assert_not_contains "$OUT" "system runs"
it "and a warning alone does not fail the check"
assert_eq "0" "$RC"
