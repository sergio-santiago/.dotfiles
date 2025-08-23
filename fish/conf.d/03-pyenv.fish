# ~/.config/fish/conf.d/03-pyenv.fish
# ==============================================================================
# 🐍 Pyenv initialization (minimal Homebrew setup)
# ------------------------------------------------------------------------------
# Sets up pyenv for managing multiple Python versions. Ensures shims are
# initialized only in interactive shells where pyenv is available.
#
# Load scope:
#   - Interactive shells only (guarded by `status --is-interactive`).
#
# Dependencies:
#   - pyenv (installed via Homebrew)
#
# Notes:
#   - PYENV_ROOT defaults to ~/.pyenv
#   - Shims are not loaded if pyenv is not found in PATH
# ==============================================================================
set -gx PYENV_ROOT $HOME/.pyenv
type -q pyenv; and status --is-interactive; and pyenv init - | source
