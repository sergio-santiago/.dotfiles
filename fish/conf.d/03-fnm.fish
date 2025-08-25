# ~/.config/fish/conf.d/03-fnm.fish
# ==============================================================================
# 🟢 FNM (Fast Node Manager) initialization
# ------------------------------------------------------------------------------
# Purpose:
#   - Initialize FNM so the correct Node.js version is auto-loaded
#     when changing directories.
#
# Load scope:
#   - Interactive shells only.
#
# Dependencies:
#   - fnm (installed via Homebrew or other).
#
# Notes:
#   - `--use-on-cd` → automatically activates version when `cd` into a project dir.
#   - `--shell fish` → ensures proper Fish shell integration.
# ==============================================================================
status --is-interactive; or exit
type -q fnm; and fnm env --use-on-cd --shell fish | source
