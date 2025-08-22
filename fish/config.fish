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
    set -gx BANNER_MODE compact

    # Initialize Starship prompt (fast, highly customizable)
    if type -q starship
        starship init fish | source
    end

    # Initialize Zoxide (smart directory jumper)
    if type -q zoxide
        zoxide init fish | source
    end

    # Ensure custom bat theme is always available (rebuild cache if missing)
    if type -q bat
        set -l themes (bat --list-themes 2>/dev/null)
        if not string match -q "*linked-data-dark-rainbow*" "$themes"
            bat cache --build >/dev/null 2>&1
        end
    end

    # Display custom multi-line banner
    if functions -q banner_sergio
        banner_sergio
    end

    # fish_greeting runs automatically on shell startup (see fish/functions/)
end

# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH configuration
# ─────────────────────────────────────────────────────────────────────────────
# SSH keys and configuration are managed via:
#   ~/.dotfiles/ssh + 1Password SSH Agent
