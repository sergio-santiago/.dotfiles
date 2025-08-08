# Palette reference (from your prompt)
# sapphire:#68d5ff  peach:#ffb86c  yellow:#ffec99  green:#3dfc6e
# red:#ff4d4d       lavender:#c6a7ff  mauve:#c592ff  teal:#4af0d1
# sky:#90e8ff       crust:#000000     neutral-hi:#cdd6f4  neutral-lo:#737994

# ─── General Syntax Highlighting ───────────────────────────────────────────────
set -U fish_color_autosuggestion '#737994'          # Dim gray-blue for autosuggestions (subtle hint)
set -U fish_color_command       '#c592ff'           # Mauve for commands (matches prompt accents)
set -U fish_color_param         '#68d5ff'           # Sapphire for parameters/args (your blue chevron)
set -U fish_color_comment       '#ff8fa1'           # Flamingo for comments (soft warm contrast)
set -U fish_color_quote         '#ffb86c'           # Peach for quoted strings
set -U fish_color_redirection   '#ffec99'           # Yellow for redirections (>, >>, 2>)
set -U fish_color_end           '#c6a7ff'           # Lavender for statement separators (;, end)
set -U fish_color_error         '#ff4d4d'           # Red for errors (critical)
set -U fish_color_operator      '#3dfc6e'           # Green for |, &&, || (positive/action)
set -U fish_color_escape        '#90e8ff'           # Sky for escapes (\n, \t, \x..)
set -U fish_color_cwd           '#4af0d1'           # Teal for current directory
set -U fish_color_cwd_root      '#ff4d4d'           # Red for cwd when root
set -U fish_color_valid_path    --underline         # Underline valid paths (no color to avoid clash)

# ─── Selection & Search (editor-like) ──────────────────────────────────────────
set -U fish_color_selection         --background=#c6a7ff     # Lavender selection background
set -U fish_color_search_match      --background=#ffb86c --underline  # Peach highlight for search hits

# ─── Pager (Tab completion & history search) ───────────────────────────────────
# Selected item: lavender bg + black text (reads well; matches prompt time chip)
set -U fish_pager_color_selected_background --background=#c6a7ff
set -U fish_pager_color_selected_prefix      '#000000'
set -U fish_pager_color_selected_completion  '#000000'
set -U fish_pager_color_selected_description '#000000'

# Unselected items: neutral text; candidates in green to echo your chevrons
set -U fish_pager_color_prefix      '#cdd6f4'       # Typed prefix (neutral high)
set -U fish_pager_color_completion  '#3dfc6e'       # Candidates (green, same family as prompt arrows)
set -U fish_pager_color_description '#737994'       # Descriptions (neutral low)

# Footer (“…and N more rows”): sapphire bg + black text (distinct from selection)
set -U fish_pager_color_progress 'black' --background=#68d5ff

# ─── Additional Styling ────────────────────────────────────────────────────────
set -U fish_color_user '#ff8fa1'                     # Flamingo for usernames (keeps warm accent)
set -U fish_complete_path true                       # Include executables from $PATH in completions
