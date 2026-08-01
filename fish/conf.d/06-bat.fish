# ~/.config/fish/conf.d/06-bat.fish
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
        # If the custom theme isn't listed, rebuild the cache.
        #
        # The failure is reported rather than swallowed. Silenced, a build that can
        # never succeed, because the theme is not symlinked yet on a fresh clone or
        # because the cache directory is not writable, was retried on every single
        # shell start and cost ~300 ms each time with nothing on screen to explain it.
        # One line naming the remedy is worth more than a quiet tax.
        set -l themes (bat --list-themes 2>/dev/null)
        if not string match -q "*$BAT_THEME*" "$themes"
            if not bat cache --build >/dev/null 2>&1
                echo "bat: could not build the theme cache for '$BAT_THEME'. Run 'make link'" >&2
            end
        end
    end
end
