# ~/.config/fish/config.fish
# ==============================================================================
# 📜 Main Fish configuration file
# ------------------------------------------------------------------------------
# This file contains the main Fish shell setup, environment variables, and
# initialization logic.
# Aliases and additional functions are defined in:
#   ~/.config/fish/conf.d/aliases.fish
# ==============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Environment setup
# ─────────────────────────────────────────────────────────────────────────────

# Load Homebrew environment variables
# This ensures that tools installed via Homebrew are added to PATH and other
# environment variables are properly configured.
eval (/opt/homebrew/bin/brew shellenv)

# Initialize FNM (Fast Node Manager)
# Loads Node.js version manager into the shell.
fnm env --use-on-cd --shell fish | source

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Interactive shell configuration
# ─────────────────────────────────────────────────────────────────────────────

if status is-interactive
    # Banner display mode: "full", "compact", or "auto" depending on terminal size
    set -gx BANNER_MODE auto

    # Initialize Starship prompt (fast, highly customizable)
    starship init fish | source

    # Initialize Zoxide (smart directory jumper)
    zoxide init fish | source

    # Display custom multi-line banner
    banner_sergio

    # fish_greeting runs automatically on shell startup (see fish/functions/)
end

# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH configuration
# ─────────────────────────────────────────────────────────────────────────────
# SSH keys and configuration are managed via:
#   ~/.dotfiles/ssh + 1Password SSH Agent
