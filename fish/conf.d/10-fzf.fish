# ~/.config/fish/conf.d/00-fzf_opts.fish
# =====================================================================
# 🎯 Global configuration for FZF in Fish
# =====================================================================
# - Defines default look & feel for FZF across all bindings.
# - Uses `fd` as a faster and smarter replacement for `find`.
# - Adds file/dir previews with `bat` and `eza`.
# - Automatically adjusts preview position depending on terminal width.
# =====================================================================

# ── 📦 Global style settings ─────────────────────────────────────────
set -gx FZF_DEFAULT_OPTS '--height=80% --layout=reverse --border=rounded --ansi --color=dark,fg:252,bg:0,fg+:15,bg+:235,hl:117,hl+:117,info:86,prompt:211,pointer:211,marker:84,spinner:216,header:183'
# Ensure truecolor support for preview color accuracy
set -q COLORTERM; or set -gx COLORTERM truecolor

# ── 🔍 Default search sources (fd) ───────────────────────────────────
# Search for files (Ctrl+T) and directories (Alt+C) with `fd`, including hidden files but excluding `.git`
set -gx FZF_DEFAULT_COMMAND  'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND   $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND    'fd --type d --hidden --follow --exclude .git'

# ── 📐 Responsive preview handling ───────────────────────────────────
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

    # Ctrl+T → File picker with bat preview
    set -gx FZF_CTRL_T_OPTS "--preview=bat\ --style=plain\ --color=always\ --wrap=auto\ --tabs=4\ --terminal-width=\$FZF_PREVIEW_COLUMNS\ --line-range=:200\ {} \
        --preview-window=$pos \
        --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"

    # Alt/Opt+C → Directory picker with eza preview
    set -gx FZF_ALT_C_OPTS "--preview=eza\ -lah\ --color=always\ --icons=auto\ --group\ --time-style=long-iso\ {} \
        --preview-window=$pos \
        --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
end

# ── ⚡ Apply settings now and on terminal resize ──────────────────────
__fzf_apply_responsive_opts
function __fzf_react_to_resize --on-variable COLUMNS
    __fzf_apply_responsive_opts
end

# zoxide interactive inherits same theme (no preview)
set -gx _ZO_FZF_OPTS $FZF_DEFAULT_OPTS
