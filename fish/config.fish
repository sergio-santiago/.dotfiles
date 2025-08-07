# ~/.config/fish/config.fish

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Environment setup
# ─────────────────────────────────────────────────────────────────────────────

# Ensure Homebrew environment variables are available
eval (/opt/homebrew/bin/brew shellenv)

# Initialize fnm (Fast Node Manager)
fnm env | source

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Interactive shell configuration
# ─────────────────────────────────────────────────────────────────────────────

if status is-interactive
    starship init fish | source # Enable Starship prompt
    banner_sergio # Custom welcome banner
    # fish_greeting runs automatically on shell startup

    # Aliases are defined in conf.d/aliases.fish
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
# And in 1Password settings: Developer → Enable "Use the SSH Agent"
