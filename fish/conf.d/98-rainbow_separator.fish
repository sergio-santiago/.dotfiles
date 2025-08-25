# ~/.config/fish/conf.d/98-rainbow_separator.fish
# ==============================================================================
# 🌈 Rainbow Separator
# ------------------------------------------------------------------------------
# Purpose:
#   - Print a full-width horizontal separator line in rainbow colors
#     after each executed command.
#
# Load scope:
#   - Interactive shells only (post-command hook).
#
# Trigger:
#   - Uses the `fish_postexec` event (fires automatically after any command).
#
# Dependencies:
#   - lolcat (for rainbow color effect)
#   - tput   (to get terminal width)
# ==============================================================================

status --is-interactive; or exit
type -q lolcat; or exit
type -q tput; or exit

function rainbow_separator --on-event fish_postexec
    # Repeat the "─" character across the terminal width
    string repeat -n (math (tput cols)) "─" |
        lolcat -t --spread=1.5  # rainbow effect with slight color spread
end
