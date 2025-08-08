# ~/.config/fish/config.fish

# Aliases are defined in conf.d/aliases.fish

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Environment setup
# ─────────────────────────────────────────────────────────────────────────────

# Load Homebrew environment variables
eval (/opt/homebrew/bin/brew shellenv)

# Initialize FNM (Fast Node Manager)
fnm env | source

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Interactive shell configuration
# ─────────────────────────────────────────────────────────────────────────────

if status is-interactive
    set -gx BANNER_MODE auto  # Banner mode: (full | compact | auto)
    starship init fish | source  # Starship prompt
    banner_sergio  # Custom welcome banner
    # fish_greeting runs automatically on shell startup
end

# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH is managed via .dotfiles/ssh configuration and 1Password SSH Agent
# ─────────────────────────────────────────────────────────────────────────────
