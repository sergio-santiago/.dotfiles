#!/usr/bin/env bash
################################################################################
# Tests for the fzf Ctrl+R widget against fish/conf.d/09-theme.fish
#
# `fzf --fish` builds the history source as a string with $fish_color_comment
# expanded into it, and fzf hands that string back to fish to run. A value fish
# can read as syntax breaks Ctrl+R outright: '#ff8fa1' turned the rest of the
# line into a comment and every Ctrl+R died with "expecting ')'".
#
# The source is taken from the installed fzf rather than copied here, so an fzf
# upgrade that changes it is tested as shipped. History is read from a scratch
# XDG_DATA_HOME, never the real one.
################################################################################

if ! command -v fish >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
  it "fish and fzf are installed (skipping the fzf widget tests without them)"
  _bad "fish or fzf not found"
  return 0
fi

THEME="$DOTFILES/fish/conf.d/09-theme.fish"

# Runs the Ctrl+R source the way the widget does. Statements in $1 run after the
# theme, so a test can override a colour. Prints fish's stderr, empty on success.
ctrl_r_run() { # [fish statements after the theme]
  env XDG_DATA_HOME="$SCRATCH/fzf-data" fish --no-config -c "
    source '$THEME'; ${1:-}
    set -l m (fzf --fish | string match -r -- '^\s*set -lx -- FZF_DEFAULT_COMMAND (\".*history.*\")\$')
    test -n \"\$m[2]\"; or begin; echo 'history source not found in fzf --fish' >&2; exit 1; end
    eval set -l cmd \$m[2]
    fish --no-config -c \"\$cmd\" >/dev/null" 2>&1
}

it "Ctrl+R runs its history source with the repo theme"
assert_eq "" "$(ctrl_r_run)"

# Proves the check above can fail: the colour that broke it must still break it.
it "Ctrl+R check fails when fish_color_comment carries a '#'"
assert_contains "$(ctrl_r_run "set -g fish_color_comment '#ff8fa1'")" "expecting ')'"
