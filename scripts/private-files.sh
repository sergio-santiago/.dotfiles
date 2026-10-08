#!/usr/bin/env bash
################################################################################
# The private file map: single source of truth
#
# Description:
#   Sourced by scripts/private-sync.sh, which copies these files between $HOME and
#   the separate private repo, and by scripts/doctor.sh, which reports when the two
#   have drifted apart. One map read by both, for the same reason scripts/links.sh
#   is one map: a copy in each would eventually disagree.
#
#   Format: "<absolute source under $HOME>|<path inside the private repo>"
#
#   An explicit list of files, never a directory, and that is the whole safety
#   property rather than a stylistic choice. ~/.aws/config holds nothing but SSO
#   profiles today, and a single `aws configure` writes long-lived keys to
#   ~/.aws/credentials right next to it. A glob over ~/.aws would have swept that
#   into a commit on the next sync. Adding a line here has to be a decision.
#
#   Not executable on its own, it only declares the array.
################################################################################

# shellcheck disable=SC2034  # read by private-sync.sh, doctor.sh and the tests that source this
PRIVATE_FILES=(
  # Host aliases with the user to log in as. Not a credential, the keys live in
  # 1Password, but it removes an attacker's enumeration step entirely.
  "$HOME/.ssh/config.private|ssh/config.private"

  # SSO profiles: account ids, role names and the start url that identifies
  # the organisation. AWS does not treat account ids as secret, but publishing
  # them enables targeted role enumeration.
  "$HOME/.aws/config|aws/config"

  # Four fish wrappers for a personal project. Three lines each and no secret in
  # them, but the name of the project, the path it lives at and what the commands
  # do are together a description of the owner rather than of the machine, and this
  # repo is public. They load from ~/.config/fish/functions-private, which is a real
  # directory: ~/.config/fish/functions is a symlink into this repo, so leaving them
  # there would have published them on the next `git add .`.
  "$HOME/.config/fish/functions-private/cc-record-start.fish|fish/functions-private/cc-record-start.fish"
  "$HOME/.config/fish/functions-private/cc-record-status.fish|fish/functions-private/cc-record-status.fish"
  "$HOME/.config/fish/functions-private/cc-record-stop.fish|fish/functions-private/cc-record-stop.fish"
  "$HOME/.config/fish/functions-private/cc-record-transcribe.fish|fish/functions-private/cc-record-transcribe.fish"

  # Work git identities: which directories commit with which employer's address.
  # Pulled in by the public git/config through an optional [include], so the public
  # repo states the mechanism without naming the employers.
  "$HOME/.config/git/config.private|git/config.private"
  "$HOME/.config/git/identity-work|git/identity-work"
  "$HOME/.config/git/identity-client|git/identity-client"

  # Link routing. Its rules name the Chrome profiles, which are named after
  # employers, so the whole file is private rather than symlinked from the repo.
  "$HOME/.config/finicky/finicky.ts|finicky/finicky.ts"

  # manual-duplex settings: the printer queue, which carries part of its MAC, the
  # calibrated pass order and a hand-written FLIP_HINT. Restore it before running
  # the tool's install.sh, which keeps a config it finds. See docs/NEW-MACHINE.md.
  "$HOME/.config/manual-duplex/config|manual-duplex/config"
)
