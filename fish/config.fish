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
# 01-local-bin.fish                             # Local user binaries PATH (~/.local/bin)
# 02-homebrew.fish                              # Homebrew environment
# 03-pyenv.fish                                 # Python runtime (pyenv)
# 04-fnm.fish                                   # Node runtime (fnm)
# 05-fzf.fish                                   # Fuzzy finder
# 06-bat.fish                                   # bat (cat replacement) config
# 07-zoxide.fish                                # zoxide (smarter cd)
# 08-aliases.fish                               # shell aliases
# 09-theme.fish                                 # theme colors (linked-data-dark-rainbow)
# 10-starship.fish                              # Starship prompt
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