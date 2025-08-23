# ~/.config/fish/conf.d/01-pyenv.fish
# ==============================================================================
# 🐍 Pyenv initialization
# ------------------------------------------------------------------------------
# Purpose:
#   - Set up pyenv for managing multiple Python versions.
#   - Initialize shims in interactive shells if pyenv is available.
#
# Load scope:
#   - Interactive shells only.
#
# Dependencies:
#   - pyenv (installed via Homebrew or other package manager).
#
# Notes:
#   - PYENV_ROOT defaults to ~/.pyenv
#   - If pyenv is not in PATH, initialization is skipped.
#   - Keep this early in load order (before Python-related tools).
# ==============================================================================

set -gx PYENV_ROOT $HOME/.pyenv
type -q pyenv; and status --is-interactive; and pyenv init - | source
