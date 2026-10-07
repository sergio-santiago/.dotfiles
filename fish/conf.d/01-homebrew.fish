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
#   - Keep this near the front of conf.d so other tools can rely on brew.
#   - It prepends on every run, so anything that must outrank Homebrew has to be
#     sourced after this file, not before. 02-local-bin.fish is the reason this one
#     moved from 02- to 01-, and carries the incident that prompted it.
# ==============================================================================

# Guarded on the binary instead of run blind. Unguarded, a machine without
# Homebrew at this path prints "command not found" at every shell start, including
# the non-interactive ones that editors and scripts spawn, and the noise appears
# where nobody is looking for it. `test -x` is a builtin, so the guard is free.
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end

# Hide Homebrew environment hints. Exported per session, not universal: a universal
# variable is stored in fish_variables, which this repo does not track, so the
# setting would outlive the line that asks for it.
set -gx HOMEBREW_NO_ENV_HINTS 1
