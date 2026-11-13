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
#   property rather than a stylistic choice. ~/.aws/config can hold nothing but SSO
#   profiles, and a single `aws configure` writes long-lived keys to
#   ~/.aws/credentials right next to it. A glob over ~/.aws would sweep that into a
#   commit on the next sync. Adding a line here has to be a decision.
#
#   Not executable on its own, it only declares the array.
################################################################################

# shellcheck disable=SC2034  # read by private-sync.sh, doctor.sh and the tests that source this
PRIVATE_FILES=(
  # Host aliases with the user to log in as. Not a credential, the keys live in
  # 1Password, but it removes an attacker's enumeration step entirely.
  "$HOME/.ssh/config.private|ssh/config.private"

  # Work git identities: which directories commit with which employer's address.
  # Pulled in by the public git/config through an optional [include], so the public
  # repo states the mechanism without naming the employers.
  "$HOME/.config/git/config.private|git/config.private"
  "$HOME/.config/git/identity-work|git/identity-work"

  # Trusted SSH signers for work directories, pointed at by identity-work. The public
  # git/allowed_signers holds only the personal address. This one lists the work
  # address first, because git reports the first principal that matches the key.
  "$HOME/.config/git/allowed_signers-work|git/allowed_signers-work"

  # Link routing. Its rules name the Chrome profiles, which are named after
  # employers, so the whole file is private rather than symlinked from the repo.
  "$HOME/.config/finicky/finicky.ts|finicky/finicky.ts"

  # manual-duplex settings: the printer queue, which carries part of its MAC, the
  # calibrated pass order and a hand-written FLIP_HINT. Restore it before running
  # the tool's install.sh, which keeps a config it finds. See docs/NEW-MACHINE.md.
  "$HOME/.config/manual-duplex/config|manual-duplex/config"
)
