# ~/.config/fish/conf.d/00-xdg_redirects.fish
# ==============================================================================
# 🧭 XDG redirects for cleaner $HOME
# ------------------------------------------------------------------------------
# Purpose:
#   - Redirects tool configs and history files to XDG-compliant locations.
#   - Keeps $HOME uncluttered while preserving functionality.
#
# Load scope:
#   - Global (applies to both interactive and non-interactive shells).
# ==============================================================================

# --- NPM ---
# Config and cache redirected to XDG paths.
# Note: PREFIX is intentionally not set to avoid conflicts with fnm.
set -x NPM_CONFIG_USERCONFIG "$HOME/.config/npm/npmrc"
set -x NPM_CONFIG_CACHE "$HOME/.cache/npm"

# --- less history ---
# Store less(1) history under ~/.cache instead of $HOME.
set -x LESSHISTFILE "$HOME/.cache/lesshst"

# --- Python REPL history ---
# Redirect interactive Python shell history file.
set -x PYTHON_HISTORY "$HOME/.cache/python_history"
