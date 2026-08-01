#!/usr/bin/env bash
################################################################################
# Tests for scripts/private-sync.sh
#
# Every case runs against a throwaway HOME and a throwaway private repo, so the
# real ~/.ssh, ~/.aws and ~/.dotfiles-private are never read or written.
#
# The property that carries the most weight here is the secret screen, and it is
# tested from both sides. A screen that misses a credential lets one into a git
# history, which is the failure this whole script exists to prevent. A screen that
# fires on `PasswordAuthentication no` is worse in practice, because a check that
# cries wolf on ordinary ssh_config gets bypassed within a week and then protects
# nothing.
#
# The other property is that a refused run refuses *everything*. Screening per file
# and copying as it went would leave the clean half staged beside a rejected run,
# and the next push would carry it without ever having said so.
################################################################################

SYNC="$DOTFILES/scripts/private-sync.sh"

# A git identity in the environment rather than in a config file: HOME is
# redirected, so git would find no user.name and every commit here would fail for
# a reason that has nothing to do with what is under test.
priv_run() { # [args...]
  OUT="$(env HOME="$CASE_HOME" DOTFILES_PRIVATE="$CASE_HOME/.dotfiles-private" \
    GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid \
    GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid \
    bash "$SYNC" "$@" 2>&1)"
  RC=$?
}

# A HOME holding believable, entirely fictional versions of the two mapped files.
fresh_priv_home() {
  CASE_HOME="$(mktemp -d "$SCRATCH/privhome.XXXXXX")"
  export CASE_HOME
  PRIV="$CASE_HOME/.dotfiles-private"
  mkdir -p "$CASE_HOME/.ssh" "$CASE_HOME/.aws"
  cat >"$CASE_HOME/.ssh/config.private" <<'EOF'
Host example-one
  HostName 203.0.113.10
  User example-user
Host example-two
  HostName 203.0.113.11
  User example-admin
  Port 2222
EOF
  cat >"$CASE_HOME/.aws/config" <<'EOF'
[profile example]
sso_account_id = 111122223333
sso_role_name = ExampleRole
region = eu-west-1
EOF
}

# ── init makes a local repo and nothing else ────────────────────────────────
fresh_priv_home
priv_run init

it "init exits 0"
assert_eq 0 "$RC"

it "init creates the repo"
assert_file "$PRIV/.git"

it "the private repo is 0700, since it holds the host list"
assert_eq 700 "$(stat -f '%Lp' "$PRIV" 2>/dev/null)"

it "init writes a .gitignore as a second layer against credential filenames"
assert_file "$PRIV/.gitignore"

it "that .gitignore refuses an ~/.aws/credentials added by hand"
assert_contains "$(cat "$PRIV/.gitignore")" "credentials"

# The one irreversible step in this script. It has to stay a printed instruction.
it "init creates no remote, because that is what publishes the host list"
assert_eq "" "$(git -C "$PRIV" remote 2>/dev/null)"

it "init says how to add the remote instead of adding it"
assert_contains "$OUT" "gh repo create dotfiles-private --private"

it "init is idempotent"
priv_run init
assert_eq 0 "$RC"

# ── A dry run changes nothing ───────────────────────────────────────────────
fresh_priv_home
priv_run init --dry-run
it "init --dry-run creates no repo at all"
assert_no_file "$PRIV"

fresh_priv_home
priv_run init >/dev/null
priv_run push --dry-run

it "push --dry-run exits 0"
assert_eq 0 "$RC"

it "push --dry-run says so, so it cannot be mistaken for a real run"
assert_contains "$OUT" "Dry run"

it "push --dry-run copies no file into the repo"
assert_no_file "$PRIV/ssh/config.private"

it "push --dry-run makes no commit"
assert_eq "" "$(git -C "$PRIV" log --oneline 2>/dev/null)"

it "push --dry-run announces the copies in the future tense"
assert_contains "$OUT" "would copy"

# ── A real push copies, tightens the mode and commits ───────────────────────
priv_run push
it "push exits 0"
assert_eq 0 "$RC"

it "the SSH config lands in the repo"
assert_file "$PRIV/ssh/config.private"

it "the AWS config lands in the repo"
assert_file "$PRIV/aws/config"

it "the copy is 0600 and not whatever the umask happened to be"
assert_eq 600 "$(stat -f '%Lp' "$PRIV/ssh/config.private" 2>/dev/null)"

it "the copy is byte for byte the original"
assert_eq 0 "$(cmp -s "$CASE_HOME/.ssh/config.private" "$PRIV/ssh/config.private" && echo 0 || echo 1)"

it "push commits the result"
assert_eq 1 "$(git -C "$PRIV" log --oneline 2>/dev/null | grep -c .)"

it "the commit message follows the repo's conventional-commits rule"
assert_contains "$(git -C "$PRIV" log -1 --pretty=%s)" "chore: sync private config"

it "with no remote it says so rather than pretending it is backed up"
assert_contains "$OUT" "no remote"

# A second push must not manufacture an empty commit, or the log fills with noise
# that hides the pushes that changed something.
priv_run push
it "a second push exits 0"
assert_eq 0 "$RC"

it "a second push adds no empty commit"
assert_eq 1 "$(git -C "$PRIV" log --oneline 2>/dev/null | grep -c .)"

it "and it says there was nothing to do"
assert_contains "$OUT" "nothing changed"

# An existing 0600 copy must stay 0600. chmod is explicit in the script precisely
# because cp onto an existing file keeps that file's old mode, so a copy once
# written at 0644 would never be corrected by umask alone.
chmod 644 "$PRIV/ssh/config.private"
printf 'Host example-three\n  HostName 203.0.113.12\n' >>"$CASE_HOME/.ssh/config.private"
priv_run push
it "a later push re-tightens a copy whose mode had been loosened"
assert_eq 600 "$(stat -f '%Lp' "$PRIV/ssh/config.private" 2>/dev/null)"

# ── The secret screen, from both sides ──────────────────────────────────────
# Injected into the SSH config, one line at a time, on top of a known-clean file.
# Every value below is a documented example or an obvious placeholder.
screen_verdict() { # line-to-inject → "TRIP" or "CLEAN"
  cat >"$CASE_HOME/.ssh/config.private" <<'EOF'
Host example-one
  HostName 203.0.113.10
  User example-user
EOF
  printf '%s\n' "$1" >>"$CASE_HOME/.ssh/config.private"
  priv_run scan
  ((RC == 0)) && printf 'CLEAN' || printf 'TRIP'
}

fresh_priv_home
priv_run init >/dev/null

it "a private key block is caught"
assert_eq TRIP "$(screen_verdict '-----BEGIN OPENSSH PRIVATE KEY-----')"

it "an AWS access key id is caught"
assert_eq TRIP "$(screen_verdict '# AKIAIOSFODNN7EXAMPLE')"

it "an aws_secret_access_key setting is caught"
assert_eq TRIP "$(screen_verdict 'aws_secret_access_key = wJalrXUtnFEMIexampleexample')"

it "an AWS session token setting is caught"
assert_eq TRIP "$(screen_verdict 'aws_session_token = IQoJb3JpZ2luX2VjEXAMPLE')"

it "a GitHub token is caught"
assert_eq TRIP "$(screen_verdict '# ghp_000000000000000000000000000000000000')"

it "a GitHub fine-grained token is caught"
assert_eq TRIP "$(screen_verdict '# github_pat_00000000000000000000_0000000000')"

it "a Slack token is caught"
assert_eq TRIP "$(screen_verdict '# xoxb-0000000000-000000000000-EXAMPLE')"

it "an sk- style API key is caught"
assert_eq TRIP "$(screen_verdict '# sk-ant-api03-000000000000000000000000')"

it "a password written into a comment is caught"
assert_eq TRIP "$(screen_verdict '# password=notarealpassword')"

it "a passphrase written into a comment is caught"
assert_eq TRIP "$(screen_verdict '# passphrase: notarealpassphrase')"

# The other half, and the half that decides whether this check survives contact
# with real use. Every line below is ordinary ssh_config.
it "PasswordAuthentication no does not trip it"
assert_eq CLEAN "$(screen_verdict '  PasswordAuthentication no')"

it "IdentityFile does not trip it, since it names a path and not a key"
assert_eq CLEAN "$(screen_verdict '  IdentityFile ~/.ssh/id_ed25519')"

it "IdentitiesOnly does not trip it"
assert_eq CLEAN "$(screen_verdict '  IdentitiesOnly yes')"

it "ProxyJump does not trip it"
assert_eq CLEAN "$(screen_verdict '  ProxyJump bastion')"

it "the word secret in a plain comment does not trip it"
assert_eq CLEAN "$(screen_verdict '# the secret sauce is documented elsewhere')"

it "a clean file scans clean"
assert_eq CLEAN "$(screen_verdict '  Compression yes')"

# ── A refused run refuses everything ────────────────────────────────────────
fresh_priv_home
priv_run init >/dev/null
priv_run push >/dev/null
BEFORE_SUM="$(cksum <"$PRIV/ssh/config.private")"

printf 'aws_secret_access_key = wJalrXUtnFEMIexampleexample\n' >>"$CASE_HOME/.aws/config"
printf 'Host example-clean\n  HostName 203.0.113.99\n' >>"$CASE_HOME/.ssh/config.private"
priv_run push

it "a push carrying a credential exits 1"
assert_eq 1 "$RC"

it "it names the file and what tripped"
assert_contains "$OUT" "a long-lived AWS secret key"

# The screen prints line numbers, never the line. A check that echoes the secret it
# caught has just copied it into the scrollback, the terminal log and CI output.
it "it never prints the matched secret itself"
assert_not_contains "$OUT" "wJalrXUtnFEMIexampleexample"

it "the unrelated clean file is not copied either, so the whole run is refused"
assert_eq "$BEFORE_SUM" "$(cksum <"$PRIV/ssh/config.private")"

it "and it says what to do about it"
assert_contains "$OUT" "1Password"

# ── pull moves anything in the way aside ────────────────────────────────────
fresh_priv_home
priv_run init >/dev/null
priv_run push >/dev/null
printf 'Host only-on-this-laptop\n  HostName 203.0.113.77\n' >>"$CASE_HOME/.ssh/config.private"
MINE="$(cat "$CASE_HOME/.ssh/config.private")"

priv_run pull --dry-run
it "pull --dry-run announces the backup it would take"
assert_contains "$OUT" "would back up"

it "pull --dry-run leaves the local file exactly as it was"
assert_eq "$MINE" "$(cat "$CASE_HOME/.ssh/config.private")"

it "pull --dry-run creates no backup directory"
assert_no_file "$CASE_HOME/.dotfiles-backup"

priv_run pull
it "pull exits 0"
assert_eq 0 "$RC"

it "pull backs up the local version before overwriting it"
assert_eq "$MINE" \
  "$(find "$CASE_HOME/.dotfiles-backup" -name config.private -exec cat {} \; 2>/dev/null)"

it "pull restores the repo's version"
assert_eq 0 "$(cmp -s "$CASE_HOME/.ssh/config.private" "$PRIV/ssh/config.private" && echo 0 || echo 1)"

it "the restored file is 0600"
assert_eq 600 "$(stat -f '%Lp' "$CASE_HOME/.ssh/config.private" 2>/dev/null)"

# ── status ──────────────────────────────────────────────────────────────────
fresh_priv_home
priv_run status
it "status on a machine with no private repo says it is not set up"
assert_contains "$OUT" "not set up"

it "and it still exits 0, because an optional feature being absent is not a failure"
assert_eq 0 "$RC"

priv_run init >/dev/null
priv_run push >/dev/null
priv_run status
it "status reports a file that matches as in sync"
assert_contains "$OUT" "in sync"

printf 'Host drifted\n  HostName 203.0.113.55\n' >>"$CASE_HOME/.ssh/config.private"
priv_run status
it "status notices a local edit that has not been pushed"
assert_contains "$OUT" "differs from the pushed copy"

it "status warns that a repo with no remote is not backed up anywhere"
assert_contains "$OUT" "no remote"

# ── Argument handling matches the other scripts' contract ───────────────────
fresh_priv_home
priv_run --help
it "--help exits 0"
assert_eq 0 "$RC"

it "--help lists the commands"
assert_contains "$OUT" "private-sync.sh"

it "--help creates nothing"
assert_no_file "$PRIV"

priv_run --nope
it "an unknown flag exits 2, distinct from a failed run"
assert_eq 2 "$RC"

priv_run push pull
it "two commands at once are rejected rather than silently picking one"
assert_eq 2 "$RC"

# ── The map is the single source of truth ───────────────────────────────────
# doctor.sh reports this drift too. It has to read the same map, or the sync and
# the health check end up disagreeing about which files are in scope, which is the
# exact failure scripts/links.sh was factored out to avoid.
it "doctor.sh reads the same private file map instead of keeping its own copy"
assert_contains "$(cat "$DOTFILES/scripts/doctor.sh")" "private-files.sh"

it "private-sync.sh reads it too"
assert_contains "$(cat "$SYNC")" "private-files.sh"

# shellcheck source=../private-files.sh
source "$DOTFILES/scripts/private-files.sh"
it "the map is not empty, so every comparison above proves something"
assert_eq 0 "$([[ ${#PRIVATE_FILES[@]} -gt 0 ]] && echo 0 || echo 1)"

# A directory in the map would defeat the point: ~/.aws/config is safe to sync and
# ~/.aws/credentials, which a single `aws configure` creates beside it, is not.
it "every entry is a file and not a directory"
MAP_DIRS=""
for entry in "${PRIVATE_FILES[@]}"; do
  [[ -d "${entry%%|*}" ]] && MAP_DIRS="$MAP_DIRS ${entry%%|*}"
done
assert_eq "" "$MAP_DIRS"

unset CASE_HOME
