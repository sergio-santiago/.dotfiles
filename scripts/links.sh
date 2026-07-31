#!/usr/bin/env bash
################################################################################
# The symlink map — single source of truth
#
# Description:
#   Sourced by scripts/install.sh, which creates these links, and by
#   scripts/doctor.sh, which verifies them. One map read by both, so what gets
#   created and what gets checked cannot disagree — a copy in each would drift,
#   and a doctor that checks a shorter list reports all-green over a gap.
#
#   Format: "<path relative to the repo>|<absolute destination>"
#
#   Not executable on its own — it only declares the array.
################################################################################

LINKS=(
  "ssh/config|$HOME/.ssh/config"
  "fish/conf.d|$HOME/.config/fish/conf.d"
  "fish/functions|$HOME/.config/fish/functions"
  "fish/config.fish|$HOME/.config/fish/config.fish"
  "starship/starship.toml|$HOME/.config/starship.toml"
  "git/config|$HOME/.config/git/config"
  "micro/settings.json|$HOME/.config/micro/settings.json"
  "micro/colorschemes/linked-data-dark-rainbow.micro|$HOME/.config/micro/colorschemes/linked-data-dark-rainbow.micro"
  "bat/themes|$HOME/.config/bat/themes"
  "finicky/finicky.ts|$HOME/.config/finicky/finicky.ts"
  "claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "claude/settings.json|$HOME/.claude/settings.json"
  "claude/statusline.sh|$HOME/.claude/statusline.sh"
  "claude/hooks|$HOME/.claude/hooks"
  "claude/rules|$HOME/.claude/rules"
  "claude/speak-lib.sh|$HOME/.claude/speak-lib.sh"
  "claude/speak-clean.py|$HOME/.claude/speak-clean.py"
  "claude/skills/speak|$HOME/.claude/skills/speak"
  "scripts/bin/speak|$HOME/.local/bin/speak"
  "btop/btop.conf|$HOME/.config/btop/btop.conf"
  "gh/config.yml|$HOME/.config/gh/config.yml"
)
