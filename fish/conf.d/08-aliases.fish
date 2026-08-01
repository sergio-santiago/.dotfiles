# ~/.config/fish/conf.d/08-aliases.fish
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

# ──────────────────────────────────────────────────────────────────────────────
# 📁 Listing (eza)
# ──────────────────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────────────────
# 📄 File viewing (bat)
# ──────────────────────────────────────────────────────────────────────────────
if type -q bat
    function _view --wraps bat --description 'bat viewer with terminal width wrap'
        # The width is tested rather than chained off `set`, which always succeeds:
        # `set -l cols $COLUMNS; or set -l cols 120` never reached the fallback, so an
        # unset COLUMNS handed bat a bare `--terminal-width=` instead of a number.
        set -l cols $COLUMNS
        test -n "$cols"; or set cols 120
        command bat --paging=never --style=plain --wrap=auto --terminal-width=$cols --tabs=4 $argv
    end
    alias view="_view"
    alias v="_view"
end

# ──────────────────────────────────────────────────────────────────────────────
# ✏️ Editors
# ──────────────────────────────────────────────────────────────────────────────
if type -q micro
    set -gx EDITOR micro
    alias edit="micro"
    alias e="micro"
end

if type -q code
    set -gx VISUAL "code --wait"
end

# ──────────────────────────────────────────────────────────────────────────────
# 📋 Clipboard
# ──────────────────────────────────────────────────────────────────────────────
if type -q pbcopy
    alias copy="pbcopy"
end
# `pst`, not `paste`: that name belongs to /usr/bin/paste, and pbpaste ignores file
# arguments rather than rejecting them. Shadowed, a line pasted from documentation
# like `paste -d, ids.txt names.txt > out.csv` wrote the clipboard into out.csv and
# exited 0, so the mistake only surfaced later in whatever read the file.
if type -q pbpaste
    alias pst="pbpaste"
end

# ──────────────────────────────────────────────────────────────────────────────
# ⚙️ Development tools
# ──────────────────────────────────────────────────────────────────────────────
alias m="make"
if type -q claude
    alias c="claude"
    alias c-yolo="claude --dangerously-skip-permissions"
end
if type -q fnm
    alias nvm="fnm"
end

# ──────────────────────────────────────────────────────────────────────────────
# 🧰 Git & VCS
# ──────────────────────────────────────────────────────────────────────────────
if type -q git
    function git-graph --description "Pretty git log with graph and decorations"
        git log \
            --all \
            --graph \
            --decorate \
            --abbrev-commit \
            --date=relative \
            --decorate-refs-exclude='refs/remotes/*/HEAD' \
            --pretty=format:'%C(auto)%h%C(reset) %C(magenta)%d%C(reset)%n  %s%n  %C(green)(%cr)%C(reset) %C(bold blue)<%an>%C(reset)%n'
    end
    alias gg="git-graph"

    function git-patch --description "Apply patch from clipboard via pbpaste"
        pbpaste | git apply $argv
    end
    alias gp="git-patch"
end

# ──────────────────────────────────────────────────────────────────────────────
# 📊 System
# ──────────────────────────────────────────────────────────────────────────────
if type -q btop
    alias monitor="btop"
end

# ──────────────────────────────────────────────────────────────────────────────
# 🍺 Homebrew
# ──────────────────────────────────────────────────────────────────────────────
if type -q brew
    # The logic lives in scripts/bin/brew-maintenance, linked onto $PATH by
    # `make link`, so it is testable, works from any shell, and its steps do not
    # cancel each other the way a chain of && did.
    alias bm="brew-maintenance"

    function brew-installed --description 'List formulas, casks, and taps installed manually'
        printf "== 🍃 Formulae (manual) ==\n"
        brew leaves
        printf "\n== 📦 Casks ==\n"
        brew list --casks
        printf "\n== 🔗 Taps ==\n"
        brew tap
    end
    alias bi="brew-installed"
end
