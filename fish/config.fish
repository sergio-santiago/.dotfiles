# ~/.config/fish/config.fish
# ==============================================================================
#
# ─────────────────────────────────────────────────────────────────────────────
# 📜 Main Fish configuration (config.fish)
# ------------------------------------------------------------------------------
# Purpose:
#   - Intentionally minimal. No executable logic here.
#   - All runtime configuration is modularized under ~/.config/fish/conf.d/*.fish
#   - Custom functions are defined under ~/.config/fish/functions/*.fish
#
# Loading order:
#   - Fish automatically sources all files in conf.d/ in lexicographic order.
#   - Used numeric prefixes (00-, 01-, 02-, …, 99-) to control priority.
#
# ─────────────────────────────────────────────────────────────────────────────
# 📂 conf.d load order reference
# ─────────────────────────────────────────────────────────────────────────────
# 00-xdg_redirects.fish                         # XDG base dirs first (env vars redirection)
# 01-homebrew.fish                              # Homebrew environment
# 02-pyenv.fish                                 # Python runtime (pyenv)
# 03-fnm.fish                                   # Node runtime (fnm)
# 04-fzf.fish                                   # Fuzzy finder
# 05-bat.fish                                   # bat (cat replacement) config
# 06-zoxide.fish                                # zoxide (smarter cd)
# 07-aliases.fish                               # shell aliases
# 08-fish_colors_linked_data_dark_rainbow.fish  # theme colors
# 09-starship.fish                              # Starship prompt
# 98-rainbow_separator.fish                     # rainbow separator (cosmetic, near the end)
# 99-banner.fish                                # custom banner (cosmetic, always last)
#
# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH configuration
# ─────────────────────────────────────────────────────────────────────────────
# SSH keys and configuration are managed via:
#   ~/.dotfiles/ssh  +  1Password SSH Agent
#
# ==============================================================================
# End of config.fish — all logic is delegated to conf.d/ and functions/
