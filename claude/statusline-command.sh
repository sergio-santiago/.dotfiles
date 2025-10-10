#!/bin/bash
# Claude Code status line - minimal and useful

# Read JSON input
input=$(cat)

# Extract info
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# Get folder name
folder_name=$(basename "$current_dir")

# Git info with clear status indicators
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")

  # Count different types of changes
  modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

  # Build status string with separators
  status_parts=""
  [ "$staged" -gt 0 ] && status_parts="${status_parts} ✓${staged}"
  [ "$modified" -gt 0 ] && status_parts="${status_parts} ~${modified}"
  [ "$untracked" -gt 0 ] && status_parts="${status_parts} +${untracked}"

  if [ -z "$status_parts" ]; then
    git_info="$branch"
  else
    git_info="$branch$status_parts"
  fi
fi

# Build status line
# Colors: sapphire=#68d5ff, peach=#ffb86c, yellow=#ffec99, lavender=#c6a7ff, green=#3dfc6e, gray=#6c7086
printf "\033[38;2;104;213;255m%s\033[0m" "$folder_name"
[ -n "$git_info" ] && printf " \033[38;2;108;112;134m󰇝\033[0m \033[38;2;255;236;153m%s\033[0m" "$git_info"
printf " \033[38;2;108;112;134m󰇝\033[0m \033[38;2;61;252;110m󰫈 %s\033[0m" "$model_name"
