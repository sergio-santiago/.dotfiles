# ~/.config/fish/conf.d/05-fzf.fish
# ==============================================================================
# 🎯 FZF global configuration (interactive only)
# ------------------------------------------------------------------------------
# Purpose:
#   - Define default look & feel for FZF across all bindings.
#   - Use `fd` as a faster/smarter default source when available (fallback to find).
#   - Add file/dir previews (bat/eza) with responsive preview window.
#
# Load scope:
#   - Interactive shells only.
#
# Dependencies:
#   - Required: fzf
#   - Optional: fd (sources), bat (file preview), eza (dir preview)
# ==============================================================================

# ── 📦 Global style settings ────────────────────────────────────────────────
# Colors synchronized with Linked Data Dark Rainbow palette (COLORS.md)
# fg:231(white) bg:16(black) fg+:231(white) bg+:59(neutral grey, see COLORS.md)
# hl:117(blue) hl+:122(cyan) info:183(purple) prompt:212(pink)
# pointer:212(pink) marker:84(green) spinner:222(orange) header:183(mauve)
#
# Above the interactive guard on purpose, the way 06-bat.fish exports BAT_THEME:
# these are pure exports with nothing to initialize. Below the guard, a
# non-interactive `fish -c '… | fzf'` never reached them and fell back to whatever
# was left in the untracked fish_variables, which on a long-lived machine is a
# universal export from before this palette existed. The documented colors have to
# be the ones that apply, not the ones that apply only when a human is watching.
set -gx FZF_DEFAULT_OPTS '--height=80% --layout=reverse --border=rounded --ansi --color=dark,fg:231,bg:16,fg+:231,bg+:59,hl:117,hl+:122,info:183,prompt:212,pointer:212,marker:84,spinner:222,header:183'
set -q COLORTERM; or set -gx COLORTERM truecolor

status --is-interactive; or exit
type -q fzf; or exit

# ── 🔍 Default search sources (fd with fallback) ────────────────────────────
if type -q fd
    set -gx FZF_DEFAULT_COMMAND  'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND   $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND    'fd --type d --hidden --follow --exclude .git'
else
    set -gx FZF_DEFAULT_COMMAND  "find -L . -type f -not -path '*/.git/*' 2>/dev/null"
    set -gx FZF_CTRL_T_COMMAND   $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND    "find -L . -type d -not -path '*/.git/*' 2>/dev/null"
end

# ── 📐 Responsive preview handling ──────────────────────────────────────────
function __fzf_apply_responsive_opts
    # Width breakpoints (columns)
    set -l narrow 120
    set -l very_narrow 90

    # Default preview position → right
    set -l pos 'right:60%:wrap'
    if test "$COLUMNS" -lt $narrow
        set pos 'down:60%:wrap'
        if test "$COLUMNS" -lt $very_narrow
            set pos 'down:50%:wrap'
        end
    end

    # Ctrl+T → File picker (prefer bat, else no preview)
    if type -q bat
        set -gx FZF_CTRL_T_OPTS "--preview=bat\ --style=plain\ --color=always\ --wrap=auto\ --tabs=4\ --terminal-width=\$FZF_PREVIEW_COLUMNS\ --line-range=:200\ {} \
            --preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    else
        set -gx FZF_CTRL_T_OPTS "--preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    end

    # Alt/Opt+C → Directory picker (prefer eza, else ls -la)
    if type -q eza
        set -gx FZF_ALT_C_OPTS "--preview=eza\ -lah\ --color=always\ --icons=auto\ --group\ --time-style=long-iso\ {} \
            --preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    else
        set -gx FZF_ALT_C_OPTS "--preview=ls\ -la\ {}\ 2>/dev/null \
            --preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    end
end

# ── ⚡ Apply settings now and on terminal resize ────────────────────────────
__fzf_apply_responsive_opts
function __fzf_react_to_resize --on-variable COLUMNS
    __fzf_apply_responsive_opts
end

# ── 🎨 Zoxide integration ───────────────────────────────────────────────────
# Nothing to set. `_ZO_FZF_OPTS` *replaces* zoxide's own fzf arguments rather than
# adding to them, and setting it to FZF_DEFAULT_OPTS cost `zi` the sixteen flags
# zoxide passes for a reason. Verified with an fzf stub that dumps its argv:
#
#   unset   --delimiter=\t --nth=2 --read0 --exact --no-sort --exit-0 --cycle
#           --keep-right --bind=ctrl-z:ignore,btab:up,tab:down --height=45%
#           --info=inline --layout=reverse --border=sharp --tabstop=1
#           --preview='ls -Cp {2..}' --preview-window=down,30%,sharp
#   set     --delimiter=\t --nth=2 --read0
#
# `--no-sort` is the one that matters: without it fzf reorders the candidates by its
# own fuzzy score and throws away the frecency ranking, which is the whole reason to
# use zoxide instead of cd. `--exact` and the directory preview went with it.
#
# The colors were never the reason to set it: FZF_DEFAULT_OPTS is exported above and
# the fzf that zoxide spawns inherits it as an environment variable, palette and all.
# zoxide's argv then overrides height and border for `zi` alone, which is its default
# look and a fair price for a list that is ordered correctly.
