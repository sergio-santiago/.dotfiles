# ~/.config/fish/functions/fish_user_key_bindings.fish
# This function is automatically called by Fish at startup to define custom key bindings.
# Running `fzf --fish | source` loads the official fzf keybindings for Fish, which include:
#   - Ctrl+R → Interactive command history search
#   - Ctrl+T → Fuzzy file search (inserts selected path into the command line)
#   - Alt+C  → Fuzzy directory search (cd into selected folder)
# These bindings respect any options set in FZF_*_OPTS (see fish/conf.d/00-fzf_opts.fish).
function fish_user_key_bindings
  fzf --fish | source
end
