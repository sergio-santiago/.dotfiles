# ~/.config/fish/config.fish

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Environment setup
# ─────────────────────────────────────────────────────────────────────────────

# Ensure Homebrew environment variables are available
eval (/opt/homebrew/bin/brew shellenv)

# Enable Nerd Fonts support for bobthefish theme
set -g theme_nerd_fonts yes

# Initialize fnm (Fast Node Manager)
fnm env | source

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Interactive shell configuration
# ─────────────────────────────────────────────────────────────────────────────

if status is-interactive
    banner_sergio # Custom welcome banner

    # Aliases are defined in conf.d/aliases.fish
    # Note: Prompt and plugins are managed by Fisher (e.g., bobthefish)
end

# ─────────────────────────────────────────────────────────────────────────────
# 🔐 SSH configuration
# ─────────────────────────────────────────────────────────────────────────────

# If you're using 1Password SSH agent, do NOT start ssh-agent or use ssh-add manually.
# Make sure the following is configured instead:
#
#   ~/.ssh/config:
#   Host *
#     IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
#
# And in 1Password settings: Developer → Enable "Integrate with SSH"
