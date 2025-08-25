# ~/.config/fish/conf.d/05-bat.fish
# ==============================================================================
# 📄 bat configuration
# ------------------------------------------------------------------------------
# Purpose:
#   - Set the default bat theme to the versioned one in your dotfiles.
#   - Ensure the theme cache exists (rebuild on interactive shells if missing).
#
# Layout:
#   - Theme file lives in ~/.dotfiles/bat/themes (symlinked to ~/.config/bat/themes).
#   - Other runtime options (wrap, width, tabs) are controlled by the `view` alias.
#
# Load scope:
#   - Exports (BAT_THEME) apply to all shells.
#   - Cache check/rebuild runs only on interactive shells.
# ==============================================================================

# Default theme for bat (exported globally so any call to bat uses it)
set -gx BAT_THEME linked-data-dark-rainbow

# Rebuild theme cache only when interactive and if bat exists
if status --is-interactive
    if type -q bat
        # If the custom theme isn't listed, rebuild the cache quietly
        set -l themes (bat --list-themes 2>/dev/null)
        if not string match -q "*$BAT_THEME*" "$themes"
            bat cache --build >/dev/null 2>&1
        end
    end
end
