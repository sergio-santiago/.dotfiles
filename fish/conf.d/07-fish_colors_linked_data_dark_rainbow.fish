# ~/.config/fish/conf.d/07-fish_colors_linked_data_dark_rainbow.fish
# ==============================================================================
# 🌈 Fish syntax highlighting & pager colors
# ------------------------------------------------------------------------------
# Purpose:
#   - Define the "linked_data_dark_rainbow" color theme for Fish.
#   - Provides consistent look with Starship + bat + Micro theme.
#
# Load scope:
#   - Universal variables (`set -U`) apply persistently across all sessions.
#
# Notes:
#   - Run `fish_config theme show` to preview active colors.
#   - To reset, use `set -eU <var>`.
# ==============================================================================

# ─── General Syntax Highlighting ───────────────────────────────────────────────
set -U fish_color_autosuggestion '#737994'     # Dim gray-blue for autosuggestions (subtle hint)
set -U fish_color_command       '#cca5ff'      # Mauve for commands (matches prompt accents)
set -U fish_color_param         '#68d5ff'      # Sapphire for parameters/args (blue chevron)
set -U fish_color_comment       '#ff8fa1'      # Flamingo for comments (warm contrast)
set -U fish_color_quote         '#ffb86c'      # Peach for quoted strings
set -U fish_color_redirection   '#ffd54a'      # Bright yellow for redirections (>, >>, 2>)
set -U fish_color_end           '#90e8ff'      # Sky blue for separators (;, end)
set -U fish_color_error         '#ff4d4d'      # Red for errors (critical)
set -U fish_color_operator      '#5efc94'      # Soft green for |, &&, ||
set -U fish_color_escape        '#90e8ff'      # Sky blue for escapes (\n, \t, \x..)
set -U fish_color_cwd           '#4af0d1'      # Teal for current directory
set -U fish_color_cwd_root      '#ff4d4d'      # Red when cwd is root
set -U fish_color_valid_path    --underline    # Underline valid paths (avoid color clash)

# ─── Selection & Search ────────────────────────────────────────────────────────
set -U fish_color_selection    --background=#c6a7ff
set -U fish_color_search_match --background=#ffb86c --underline

# ─── Pager (Tab completion & history search) ───────────────────────────────────
# Selected item → lavender bg + black text
set -U fish_pager_color_selected_background --background=#c6a7ff
set -U fish_pager_color_selected_prefix      '#000000'
set -U fish_pager_color_selected_completion  '#000000'
set -U fish_pager_color_selected_description '#000000'

# Unselected items
set -U fish_pager_color_prefix      '#cdd6f4'  # Typed prefix (neutral high)
set -U fish_pager_color_completion  '#68d5ff'  # Candidates (sapphire, matches arrows)
set -U fish_pager_color_description '#737994'  # Descriptions (neutral low)

# Footer (progress line “…and N more rows”)
set -U fish_pager_color_progress '#000000' --background=#68d5ff

# ─── Additional Styling ────────────────────────────────────────────────────────
set -U fish_color_user '#ff8fa1'   # Flamingo for usernames (warm accent)
