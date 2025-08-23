# ~/.config/fish/conf.d/xdg_redirects.fish
# ==============================================================================
# 🧭 XDG redirects for cleaner $HOME
# ------------------------------------------------------------------------------
# Redirects tool configs and history files to XDG-compliant locations.
# Keeps $HOME uncluttered while preserving functionality.
# Loaded in every shell (interactive and non-interactive).
# ==============================================================================

# --- NPM ---
# Config and cache moved under XDG paths.
# Note: PREFIX is not set to avoid conflicts with fnm.
set -x NPM_CONFIG_USERCONFIG "$HOME/.config/npm/npmrc"
set -x NPM_CONFIG_CACHE "$HOME/.cache/npm"

# --- Less history ---
set -x LESSHISTFILE "$HOME/.cache/lesshst"

# --- Python history ---
set -x PYTHON_HISTORY "$HOME/.cache/python_history"
