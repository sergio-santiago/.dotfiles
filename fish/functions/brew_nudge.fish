# ~/.config/fish/functions/brew_nudge.fish
# ==============================================================================
# 🍺 Passive reminder that Homebrew maintenance is overdue
# ------------------------------------------------------------------------------
# Purpose:
#   - Suggest running `bm` when the last maintenance run is old enough.
#   - Suggestion only. It never updates anything, starts nothing in the
#     background and schedules nothing. Deciding when to update stays manual.
#
# Load scope:
#   - Autoloaded by fish, so this file costs nothing until it is called.
#     Called from fish_greeting, which means once per new shell.
#
# Cost:
#   - Two file reads, no subprocess, no network: 0.24 ms over 200 iterations,
#     against a login shell of roughly 215 ms. `brew outdated` is deliberately
#     not called here, it costs 480 ms even offline.
#   - Measure from a real terminal, not from something spawned by an editor or an
#     agent. Both the inherited environment and the parent process move the figure
#     by 50% or more in either direction, which is how a number like this gets
#     misread as having drifted when nothing changed. `make test` prints the
#     per-call cost of this function on every run.
#
# Data source:
#   - The stamp written by scripts/bin/brew-maintenance. Its mtime is the only
#     record of when maintenance last ran. Homebrew's own FETCH_HEAD cannot
#     stand in: any auto-update triggered by an unrelated `brew install` touches
#     it, so it dates the package index rather than the run.
#
# Tuning:
#   - set -U brew_nudge_days 14   (default 7, 0 disables the reminder)
# ==============================================================================

function brew_nudge --description 'Suggest brew maintenance when the last run is old'
    type -q brew; or return 0

    set -l threshold 7
    set -q brew_nudge_days; and set threshold $brew_nudge_days
    test "$threshold" -le 0; and return 0

    set -l stamp "$XDG_CACHE_HOME"
    test -z "$stamp"; and set stamp "$HOME/.cache"
    set stamp "$stamp/brew-maintenance/last-run"

    # `path mtime -R` returns the age in seconds directly, so neither `date` nor
    # `stat` has to be spawned. That is what keeps this under a millisecond.
    # Colors are interpolated instead of set around the echo, so the reset lands
    # before the newline. Emitted after it, it becomes a second line of output and
    # the banner gains a blank row.
    set -l dim (set_color -o brblack)
    set -l off (set_color normal)

    if not test -r $stamp
        echo $dim"  🍺 Homebrew maintenance has never run here. Try: bm"$off
        return 0
    end

    set -l age (path mtime -R $stamp)
    set -l days (math -s0 "floor($age / 86400)")
    test "$days" -lt "$threshold"; and return 0

    echo $dim"  🍺 Last Homebrew maintenance: $days days ago. Suggested: bm"$off
end
