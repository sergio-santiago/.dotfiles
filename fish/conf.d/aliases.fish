# ~/.config/fish/conf.d/aliases.fish
# ==============================================================================
# 🛠 Custom CLI aliases and functions for improved terminal productivity.
# Designed for Fish shell, with enhanced file navigation, listing, editing,
# and system utilities.
# ==============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# 🧭 Navigation
# ─────────────────────────────────────────────────────────────────────────────
# Jump to personal projects directory
alias zp="z ~/Projects"

# ─────────────────────────────────────────────────────────────────────────────
# 📁 Listing (eza)
# ─────────────────────────────────────────────────────────────────────────────
# Compact listing (dirs first, group names, icons)
function __list
    eza --group --icons=auto --group-directories-first $argv
end
alias list="__list"
alias l="__list"  # short alias

# Compact listing + hidden files
function __list_all
    eza -a --group --icons=auto --group-directories-first $argv
end
alias list-all="__list_all"
alias la="__list_all"  # short alias

# Detailed listing (permissions, size, owner, group, full date, git status)
function __list_long
    eza -lah --group --icons=auto --git --group-directories-first --time-style=long-iso $argv
end
alias list-long="__list_long"
alias ll="__list_long"  # short alias

# Compact tree view (use `-L<N>` to set depth)
function __list_tree
    # Note: If you want to ignore folders like .git or node_modules, add:
    #   --ignore-glob='.git|node_modules'
    eza -a --tree --group --icons=auto --git --group-directories-first $argv
end
alias list-tree="__list_tree"
alias tree="__list_tree"  # short alias

# Detailed tree view (permissions, size, owner, group, git status; use `-L<N>` to set depth)
function __list_tree_long
    # Example to ignore: --ignore-glob='.git|node_modules'
    eza -lah --tree --group --icons=auto --git --group-directories-first --time-style=long-iso $argv
end
alias list-tree-long="__list_tree_long"
alias treelong="__list_tree_long"  # short alias

# ─────────────────────────────────────────────────────────────────────────────
# 📄 File viewing (bat)
# ─────────────────────────────────────────────────────────────────────────────
# Pretty output with syntax highlighting, full style, and custom theme
function _view --wraps bat --description 'bat viewer with terminal width wrap'
    set -l cols $COLUMNS; or set -l cols 120
    command bat --paging=never --style=plain --wrap=auto --terminal-width=$cols --tabs=4 $argv
end
alias view="_view"
alias v="_view"   # short alias

# ─────────────────────────────────────────────────────────────────────────────
# ✏️ Editor
# ─────────────────────────────────────────────────────────────────────────────
# Default editor for CLI programs
set -gx EDITOR micro
alias edit="micro"
alias e="micro"

# Visual Studio Code as visual editor (blocks until closed)
set -gx VISUAL "code --wait"

# ─────────────────────────────────────────────────────────────────────────────
# 📋 Clipboard
# ─────────────────────────────────────────────────────────────────────────────
# Copy stdin to clipboard (e.g. `cat file.txt | copy`)
alias copy="pbcopy"

# Paste clipboard content to stdout (e.g. `paste > file.txt`)
alias paste="pbpaste"

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Development tools
# ─────────────────────────────────────────────────────────────────────────────
# Shorter make command
alias m="make"

# Use FNM as a drop-in replacement for nvm
alias nvm="fnm"

# ─────────────────────────────────────────────────────────────────────────────
# 🧰 Git & VCS
# ─────────────────────────────────────────────────────────────────────────────
# Visual git history graph
alias git-graph="git log --all --oneline --decorate --graph"
alias gg="git-graph"  # short alias

# Apply a git patch from clipboard
alias git-patch="pbpaste | git apply"
alias gp="git-patch"  # short alias

# ─────────────────────────────────────────────────────────────────────────────
# 📊 System
# ─────────────────────────────────────────────────────────────────────────────
# Modern system monitor (better top)
alias monitor="btop"
