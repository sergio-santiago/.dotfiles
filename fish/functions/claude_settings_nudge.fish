# ~/.config/fish/functions/claude_settings_nudge.fish
# ==============================================================================
# 🔗 Passive reminder that ~/.claude/settings.json is no longer linked
# ------------------------------------------------------------------------------
# Purpose:
#   - ~/.claude/settings.json is a symlink into this repo, and some macOS apps
#     replace it with a plain file when they save it. Without a reminder the two
#     copies drift apart for days before anyone notices.
#   - Suggestion only. It repairs nothing. `claude-settings-fix` does that, in a
#     Claude session that asks before changing anything.
#
# Load scope:
#   - Autoloaded by fish, so this file costs nothing until it is called.
#     Called from fish_greeting, which means once per new shell.
#
# Cost:
#   - Builtins only (`test -L`, `path resolve`), no subprocess, no file read.
#     `make test` prints the per-call cost on every run.
#
# Look:
#   - Same shape as brew_nudge, so every reminder reads the same way: ▌ rule,
#     bright black body, the command in cyan. Its own emoji and rule colour (pink)
#     tell it apart from the Homebrew one at a glance. Palette in docs/COLORS.md.
# ==============================================================================

function claude_settings_nudge --description 'Warn when ~/.claude/settings.json is no longer linked to the repo'
    set -l live $HOME/.claude/settings.json
    # Nothing to compare on a machine where Claude Code was never set up.
    test -e $live; or test -L $live; or return 0

    # The repo is found from this file. Autoloading goes through the symlinked
    # functions directory, and `path resolve` follows it back into the repo.
    set -l target (path resolve (status dirname)/../../claude/settings.json)
    test -L $live; and test (path resolve $live) = $target; and return 0

    set -l rule (set_color ff6cd4)
    set -l dim (set_color -o brblack)
    set -l cmd (set_color 7fffd4)
    set -l off (set_color normal)

    echo
    echo "  "$rule"▌"$off" "$dim"🔗 Claude settings no longer linked to the repo. Fix: "$off$cmd"claude-settings-fix"$off
end
