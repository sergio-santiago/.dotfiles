# ~/.config/fish/conf.d/rainbow_separator.fish
# ==============================================================================
# 🌈 Rainbow Separator
# ------------------------------------------------------------------------------
# Prints a full-width horizontal separator line in rainbow colors after
# each executed command. Triggered by the `fish_postexec` event, so it
# runs automatically after any command finishes.
#
# Dependencies:
#   - lolcat (for rainbow color effect)
#   - tput   (to get terminal width)
# ==============================================================================

function rainbow_separator --on-event fish_postexec
    # Repeat the "─" character across the entire terminal width
    string repeat -n (math (tput cols)) "─" |
        lolcat -t --spread=1.5  # rainbow effect with slight color spread
end
