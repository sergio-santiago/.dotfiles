# ~/.config/fish/conf.d/05-zoxide.fish
# ==============================================================================
# 🧭 Zoxide initialization
# ------------------------------------------------------------------------------
# Purpose:
#   - Initialize Zoxide, a smarter `cd` command with directory jumping.
#   - Provides quick navigation using frecency-based directory tracking.
#
# Load scope:
#   - Interactive shells only.
#
# Notes:
#   - Requires the `zoxide` binary to be installed (via Homebrew or other).
#   - Usage examples:
#       z foo     # jump to dir matching "foo"
#       zi foo    # interactive selection if multiple matches
# ==============================================================================

status --is-interactive; or exit
type -q zoxide; and zoxide init fish | source
