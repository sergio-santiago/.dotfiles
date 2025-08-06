# ~/.config/fish/conf.d/aliases.fish
# Custom CLI aliases for improved terminal productivity

alias l="lsd -lah"                            # List files with details and colors (using lsd)
alias ..="cd .."                              # Go up one directory
alias ...="cd ../.."                          # Go up two directories
alias cdp="cd ~/Projects"                     # Jump to personal projects directory
alias m="make"                                # Shorter make command
alias nvm="fnm"                               # Use fnm as a drop-in replacement for nvm
alias copy="pbcopy"                           # Copy stdin to clipboard (macOS), e.g. `cat file.txt | copy`
alias paste="pbpaste"                         # Paste clipboard content to stdout (macOS), e.g. `paste > file.txt`
alias cat="bat --paging=never"               # Fancy cat with syntax highlighting (bat)
alias gpatch="pbpaste | git apply"           # Apply a git patch from clipboard
alias top="btop"                              # Modern system monitor (better top)
alias git-graph="git log --all --oneline --decorate --graph"  # Visual git history
alias tree="tree -a"                          # Show full file tree including hidden files
alias btree="tree -C -a -F"                   # Colored tree with hidden files and file suffixes

# All aliases are loaded automatically via conf.d at shell startup
