# ~/.config/fish/conf.d/history_redirect.fish
# ==============================================================================
# 📚 Redirect history/cache files out of $HOME
# ------------------------------------------------------------------------------
# Moves common tool history files to ~/.cache to keep $HOME clean while
# preserving history functionality (less, Python REPL, etc.).
#
# Load scope:
#   - Global, loaded on every shell (interactive and non-interactive).
#
# Dependencies:
#   - mkdir (ensure ~/.cache exists before running if needed)
#
# Notes:
#   - Safe to source multiple times (idempotent).
#   - Use `LESSHISTFILE="-"` or `PYTHONHISTFILE="/dev/null"` if you prefer
#     disabling history completely.
# ==============================================================================

# less history
set -x LESSHISTFILE "$HOME/.cache/lesshst"

# python REPL history
set -x PYTHONHISTFILE "$HOME/.cache/python_history"
