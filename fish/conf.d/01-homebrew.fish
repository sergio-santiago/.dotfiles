# ~/.config/fish/conf.d/01-homebrew.fish
# ==============================================================================
# 🍺 Homebrew environment
# ------------------------------------------------------------------------------
# Purpose:
#   - Initialize Homebrew environment variables and update PATH/MANPATH/INFOPATH.
#   - Ensure brew-installed tools are available in all shell sessions.
#
# Load scope:
#   - Global (applies to both interactive and non-interactive shells).
#
# Dependencies:
#   - Homebrew installed under /opt/homebrew (Apple Silicon default).
#
# Notes:
#   - This uses `brew shellenv` which prepends /opt/homebrew/bin to PATH.
#   - Keep this very early in load order (01-) so other tools can rely on brew.
#   - If PATH priority issues arise (e.g. with fnm), adjust load order accordingly.
# ==============================================================================

eval (/opt/homebrew/bin/brew shellenv)
