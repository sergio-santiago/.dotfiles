# ~/.config/fish/conf.d/99-banner.fish
# ==============================================================================
# 🎨 Custom banner
# ------------------------------------------------------------------------------
# Purpose:
#   - Configure and display a custom banner at shell startup.
#   - Supports multiple display modes (full, compact, auto).
#
# Load scope:
#   - Interactive shells only (skipped for non-interactive sessions).
#
# Dependencies:
#   - Custom function `banner_sergio` defined in ~/.config/fish/functions/.
#
# Notes:
#   - `BANNER_MODE` can be set to: full | compact | auto
#   - `fish_greeting` is handled automatically if defined as a function.
#   - Placed late in load order (99-) so the banner shows after all other setup.
# ==============================================================================

status --is-interactive; or exit

# Banner display mode: full | compact | auto
set -gx BANNER_MODE compact

# Show custom banner if available
if functions -q banner_sergio
    banner_sergio
end
