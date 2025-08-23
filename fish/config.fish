# ~/.config/fish/config.fish
# ==============================================================================
# 📜 Main Fish configuration (config.fish)
# ------------------------------------------------------------------------------
# Purpose:
#   - Global shell setup (applies to all sessions).
#   - Definition of core environment variables.
#   - High-level initialization logic.
#
# Notes:
#   - Additional environment tweaks and tool integrations live in:
#       ~/.config/fish/conf.d/*.fish
#   - Custom functions are defined in:
#       ~/.config/fish/functions/*.fish
# ==============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Environment setup (global)
# ─────────────────────────────────────────────────────────────────────────────

# Homebrew environment (PATH, MANPATH, etc. for brew-installed tools).
# Keep this here so every shell —interactive or not— sees Homebrew paths.
eval (/opt/homebrew/bin/brew shellenv)

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Interactive shell configuration
# ─────────────────────────────────────────────────────────────────────────────

if status is-interactive
    # Banner display mode: "full", "compact", or "auto" depending on terminal size.
    set -gx BANNER_MODE compact

    # Custom banner (function lives under ~/.config/fish/functions/)
    if functions -q banner_sergio
        banner_sergio
    end

    # fish_greeting is handled automatically if defined as a function.
end

# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH configuration
# ─────────────────────────────────────────────────────────────────────────────
# SSH keys and configuration are managed via:
#   ~/.dotfiles/ssh  +  1Password SSH Agent
