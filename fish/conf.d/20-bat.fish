# ~/.config/fish/conf.d/20-bat.fish
# =====================================================================
# 📄 bat configuration
# ---------------------------------------------------------------------
# - Uses the theme versioned under ~/.dotfiles/bat/themes
#   (symlinked to ~/.config/bat/themes)
# - Other options (wrap, width, tabs) are controlled by the `view` alias.
# =====================================================================

# Default theme for bat
set -gx BAT_THEME linked-data-dark-rainbow

# (Optional) if you see paging issues, uncomment:
# set -gx BAT_PAGER 'less -RF'
