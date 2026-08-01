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

PRIVATE_FILES=(
  # Ten hosts with the user to log in as. Not a credential, the keys live in
  # 1Password, but it removes an attacker's enumeration step entirely.
  "$HOME/.ssh/config.private|ssh/config.private"

  # Six SSO profiles: account ids, role names and the start url that identifies
  # the organisation. AWS does not treat account ids as secret, but publishing
  # them enables targeted role enumeration.
  "$HOME/.aws/config|aws/config"
)
