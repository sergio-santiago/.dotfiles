# ~/.config/fish/conf.d/04-fzf.fish
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

status --is-interactive; or exit
type -q fzf; or exit

# ── 📦 Global style settings ─────────────────────────────────────────
set -gx FZF_DEFAULT_OPTS '--height=80% --layout=reverse --border=rounded --ansi --color=dark,fg:252,bg:0,fg+:15,bg+:235,hl:117,hl+:117,info:86,prompt:211,pointer:211,marker:84,spinner:216,header:183'
set -q COLORTERM; or set -gx COLORTERM truecolor

# ── 🔍 Default search sources (fd with fallback) ─────────────────────
if type -q fd
    set -gx FZF_DEFAULT_COMMAND  'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND   $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND    'fd --type d --hidden --follow --exclude .git'
else
    set -gx FZF_DEFAULT_COMMAND  "find -L . -type f -not -path '*/.git/*' 2>/dev/null"
    set -gx FZF_CTRL_T_COMMAND   $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND    "find -L . -type d -not -path '*/.git/*' 2>/dev/null"
end

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

    # Ctrl+T → File picker (prefer bat; else no preview)
    if type -q bat
        set -gx FZF_CTRL_T_OPTS "--preview=bat\ --style=plain\ --color=always\ --wrap=auto\ --tabs=4\ --terminal-width=\$FZF_PREVIEW_COLUMNS\ --line-range=:200\ {} \
            --preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    else
        set -gx FZF_CTRL_T_OPTS "--preview-window=$pos \
            --bind=ctrl-/:toggle-preview,ctrl-y:preview-half-page-down,ctrl-u:preview-half-page-up"
    end

    # Alt/Opt+C → Directory picker (prefer eza; else ls -la)
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

# ── ⚡ Apply settings now and on terminal resize ──────────────────────
__fzf_apply_responsive_opts
function __fzf_react_to_resize --on-variable COLUMNS
    __fzf_apply_responsive_opts
end

# zoxide's interactive mode can inherit the same theme (no preview).
set -gx _ZO_FZF_OPTS $FZF_DEFAULT_OPTS
