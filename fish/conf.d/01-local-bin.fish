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
#
# Scope:
#   - `-g`, explicitly. Left to itself, fish_add_path writes a *universal*
#     fish_user_paths, which lives in ~/.config/fish/fish_variables: a file this repo
#     does not track and `make link` does not manage, so part of PATH would be
#     defined outside version control and would survive deleting the line that asked
#     for it. Global instead means PATH is rebuilt from this file on every start,
#     which is the same reasoning 02-homebrew.fish gives for HOMEBREW_NO_ENV_HINTS.
# ==============================================================================

fish_add_path -gp "$HOME/.local/bin"
