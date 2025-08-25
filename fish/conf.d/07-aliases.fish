# ~/.config/fish/conf.d/07-aliases.fish
# ==============================================================================
# 🛠 Custom CLI aliases and helper functions
# ------------------------------------------------------------------------------
# Purpose:
#   - Improve terminal productivity with navigation, listing, editing,
#     clipboard, dev tools, Git, and system shortcuts.
#
# Load scope:
#   - Interactive shells only.
#
# Notes:
#   - Guarded with `type -q` to avoid errors if tools are missing.
#   - Prefer small functions when options are complex.
# ==============================================================================

status --is-interactive; or exit

# ─────────────────────────────────────────────────────────────────────────────
# 🧭 Navigation
# ─────────────────────────────────────────────────────────────────────────────
alias zp="z ~/Projects"

# ─────────────────────────────────────────────────────────────────────────────
# 📁 Listing (eza)
# ─────────────────────────────────────────────────────────────────────────────
if type -q eza
    function __list
        eza --group --icons=auto --group-directories-first $argv
    end
    alias list="__list"
    alias l="__list"

    function __list_all
        eza -a --group --icons=auto --group-directories-first $argv
    end
    alias list-all="__list_all"
    alias la="__list_all"

    function __list_long
        eza -lah --group --icons=auto --git --group-directories-first --time-style=long-iso $argv
    end
    alias list-long="__list_long"
    alias ll="__list_long"

    function __list_tree
        # Add exclusions with: -I='.git|node_modules'
        eza -a --tree --group --icons=auto --git --group-directories-first $argv
    end
    alias list-tree="__list_tree"
    alias tree="__list_tree"

    function __list_tree_long
        eza -lah --tree --group --icons=auto --git --group-directories-first --time-style=long-iso $argv
    end
    alias list-tree-long="__list_tree_long"
    alias treelong="__list_tree_long"
end

# ─────────────────────────────────────────────────────────────────────────────
# 📄 File viewing (bat)
# ─────────────────────────────────────────────────────────────────────────────
if type -q bat
    function _view --wraps bat --description 'bat viewer with terminal width wrap'
        set -l cols $COLUMNS; or set -l cols 120
        command bat --paging=never --style=plain --wrap=auto --terminal-width=$cols --tabs=4 $argv
    end
    alias view="_view"
    alias v="_view"
end

# ─────────────────────────────────────────────────────────────────────────────
# ✏️ Editors
# ─────────────────────────────────────────────────────────────────────────────
if type -q micro
    set -gx EDITOR micro
    alias edit="micro"
    alias e="micro"
end

if type -q code
    set -gx VISUAL "code --wait"
end

# ─────────────────────────────────────────────────────────────────────────────
# 📋 Clipboard
# ─────────────────────────────────────────────────────────────────────────────
if type -q pbcopy
    alias copy="pbcopy"
end
if type -q pbpaste
    alias paste="pbpaste"
end

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Development tools
# ─────────────────────────────────────────────────────────────────────────────
alias m="make"
if type -q fnm
    alias nvm="fnm"
end

# ─────────────────────────────────────────────────────────────────────────────
# 🧰 Git & VCS
# ─────────────────────────────────────────────────────────────────────────────
if type -q git
    alias git-graph="git log --all --oneline --decorate --graph"
    alias gg="git-graph"

    alias git-patch="pbpaste | git apply"
    alias gp="git-patch"
end

# ─────────────────────────────────────────────────────────────────────────────
# 📊 System
# ─────────────────────────────────────────────────────────────────────────────
if type -q btop
    alias monitor="btop"
end
