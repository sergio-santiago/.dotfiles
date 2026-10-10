#!/usr/bin/env bash
################################################################################
# Tests for claude/settings.json
#
# ~/.claude/settings.json is a symlink into this public repo, so anything Claude
# Code writes there lands in a tracked file. /auto-mode-setup is the dangerous
# writer: it fills autoMode.environment with a description of the repo it ran
# in, which for a private project means private data. Claude Code only reads
# autoMode from user scope, managed settings or --settings, never from a
# project's own settings, so there is no safe place for it inside this repo.
#
# The check runs against two fixtures first, so a jq path that silently stopped
# matching would fail here rather than pass the real file by accident.
################################################################################

SETTINGS="$DOTFILES/claude/settings.json"

# Prints the number of autoMode.environment entries, 0 when the key is absent.
env_entries() { # settings_file
  jq '.autoMode.environment // [] | length' "$1"
}

FIXTURES="$(mktemp -d "$SCRATCH/settings.XXXXXX")"
printf '%s\n' '{"autoMode":{"allow":["$defaults"],"environment":["**Trusted repo**: x"]}}' \
  >"$FIXTURES/leaked.json"
printf '%s\n' '{"autoMode":{"allow":["$defaults"]}}' >"$FIXTURES/clean.json"

it "the check counts a planted autoMode.environment entry"
assert_eq "1" "$(env_entries "$FIXTURES/leaked.json")"

it "the check counts nothing when only autoMode.allow is set"
assert_eq "0" "$(env_entries "$FIXTURES/clean.json")"

it "claude/settings.json is valid JSON"
if jq empty "$SETTINGS" 2>/dev/null; then _ok; else _bad "jq could not parse it"; fi

it "claude/settings.json has no autoMode.environment (it describes private repos)"
assert_eq "0" "$(env_entries "$SETTINGS")"
