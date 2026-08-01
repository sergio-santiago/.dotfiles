# ~/.config/fish/functions/fish_user_key_bindings.fish
# This function is automatically called by Fish at startup to define custom key bindings.
# Running `fzf --fish | source` loads the official fzf keybindings for Fish, which include:
#   - Ctrl+R → Interactive command history search
#   - Ctrl+T → Fuzzy file search (inserts selected path into the command line)
#   - Alt+C  → Fuzzy directory search (cd into selected folder)
# These bindings respect any options set in FZF_*_OPTS (see fish/conf.d/05-fzf.fish).
# Guarded with `type -q`, the way conf.d/05-fzf.fish is. Unguarded, a machine without
# fzf greeted every new shell with "Unknown command: fzf" and a fish code frame,
# which reads like a broken dotfiles install rather than one missing formula.
function fish_user_key_bindings
    type -q fzf; and fzf --fish | source
end
