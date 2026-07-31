#!/usr/bin/env bash
################################################################################
# The symlink map — single source of truth
#
# Description:
#   Sourced by scripts/install.sh, which creates these links, and by
#   scripts/doctor.sh, which verifies them. It lives in its own file because the
#   two used to keep a copy each and they drifted: doctor quietly stopped
#   checking the micro colorscheme and reported all-green over a list that was
#   one entry short of what the installer created.
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
