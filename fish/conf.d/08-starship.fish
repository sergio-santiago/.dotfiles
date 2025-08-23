# ~/.config/fish/conf.d/08-starship.fish
# ==============================================================================
# ⭐ Starship prompt initialization
# ------------------------------------------------------------------------------
# Purpose:
#   - Initialize the Starship prompt for interactive shells.
#   - Provides a fast, customizable and cross-shell prompt.
#
# Load scope:
#   - Interactive shells only.
#
# Notes:
#   - Configuration is stored in ~/.config/starship.toml (symlinked from dotfiles).
#   - Disable in JetBrains IDEs by overriding STARSHIP_CONFIG (see README).
# ==============================================================================

status --is-interactive; or exit
type -q starship; and starship init fish | source
