# ~/.config/fish/conf.d/01-local-bin.fish
# ==============================================================================
# 📦 Local user binaries PATH
# ------------------------------------------------------------------------------
# Purpose:
#   - Add ~/.local/bin to PATH for user-installed binaries.
#   - Follows XDG Base Directory Specification for user binaries.
#   - Used by tools like pipx, Claude native install, and other user tools.
#
# Load scope:
#   - Global (applies to both interactive and non-interactive shells).
#
# Load order:
#   - Early (01-) so user binaries are available before other tools initialize.
#
# Notes:
#   - Uses fish_add_path which is idempotent and handles duplicates.
#   - Prepends to PATH so user binaries take precedence over system ones.
# ==============================================================================

fish_add_path -p "$HOME/.local/bin"
