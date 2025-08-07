# ~/.config/fish/conf.d/aliases.fish
# Custom CLI aliases for improved terminal productivity

# ── 🧭 Navigation ─────────────────────────────────────────────
alias ..="cd .."               # Go up one directory
alias ...="cd ../.."           # Go up two directories
alias cdp="cd ~/Projects"      # Jump to personal projects directory

# ── ⚙️  Development tools ──────────────────────────────────────
alias m="make"                 # Shorter make command
alias nvm="fnm"                # Use fnm as a drop-in replacement for nvm

# ── 🧰 Git & VCS ───────────────────────────────────────────────
alias git-graph="git log --all --oneline --decorate --graph"  # Visual git history
alias gpatch="pbpaste | git apply"                            # Apply a git patch from clipboard

# ── 📁 Filesystem & Listing ───────────────────────────────────
alias l="lsd -lah"             # List files with details and colors (using lsd)
alias tree="tree -a"           # Show full tree including hidden files
alias btree="tree -C -a -F"    # Colored tree with hidden files and file suffixes
alias cat="bat --paging=never" # Fancy cat with syntax highlighting

# ── 📋 Clipboard (macOS) ───────────────────────────────────────
alias copy="pbcopy"            # Copy stdin to clipboard (macOS), e.g. `cat file.txt | copy`
alias paste="pbpaste"          # Paste clipboard content to stdout (macOS), e.g. `paste > file.txt`

# ── 📊 System ──────────────────────────────────────────────────
alias top="btop"               # Modern system monitor (better top)

# All aliases are auto-loaded at shell startup via conf.d
