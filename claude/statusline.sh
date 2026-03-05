#!/bin/bash
################################################################################
# Claude Code Status Line Generator
#
# Description:
#   Generates a colorful, informative status line for Claude Code showing:
#   - Current folder name with language-specific icon (auto-detected)
#   - Git branch and status (staged, modified, untracked, ahead/behind, stash)
#   - Active AI model name
#
# Input (via stdin):
#   JSON object with structure:
#   {
#     "model": {"display_name": "Model Name"},
#     "workspace": {"current_dir": "/path/to/dir"}
#   }
#
# Output:
#   Formatted status line with ANSI color codes
#
# Example output:
#    my-project  main ~2 +1  󰧑 Sonnet 4.5
#
################################################################################

set -euo pipefail

################################################################################
# Color definitions (RGB format) - Linked Data Dark Rainbow palette
################################################################################
readonly COLOR_BLUE='\033[38;2;104;213;255m'        # Folder name (matches #68d5ff)
readonly COLOR_YELLOW='\033[38;2;255;236;153m'      # Git branch/status (matches #ffec99)
readonly COLOR_ORANGE='\033[38;2;255;184;108m'      # Git special states: rebase, merge, detached (matches #ffb86c)
readonly COLOR_GREEN='\033[38;2;68;243;115m'        # Model name (matches #44f373)
readonly COLOR_PURPLE='\033[38;2;189;147;249m'      # Context bar (matches #bd93f9)
readonly COLOR_DIM='\033[38;2;108;108;108m'         # Dimmed elements
readonly COLOR_RESET='\033[0m'

################################################################################
# Icon definitions (Nerd Fonts)
################################################################################
readonly ICON_FOLDER=""                            # Folder/directory icon
readonly ICON_GIT_BRANCH=" "                       # Git branch icon
readonly ICON_GIT_REBASING=""                      # Rebasing state icon
readonly ICON_GIT_MERGING=""                       # Merging state icon
readonly ICON_GIT_CHERRY=""                        # Cherry-pick state icon
readonly ICON_GIT_DETACHED="󰃻"                      # Detached HEAD icon
readonly ICON_AI="󰧑"                                # AI/Model icon
readonly ICON_STAGED="✓"                            # Staged files (checkmark)
readonly ICON_MODIFIED="~"                          # Modified files (tilde)
readonly ICON_UNTRACKED="+"                         # Untracked files (plus)
readonly ICON_AHEAD="↑"                             # Commits ahead (up arrow)
readonly ICON_BEHIND="↓"                            # Commits behind (down arrow)
readonly ICON_STASH="*"                             # Stash count (asterisk)
readonly ICON_BAR_FILLED='󱑽'                  # Context bar filled segment (Nerd Font)
readonly ICON_BAR_CURRENT=''                 # Context bar current position (Nerd Font)
readonly ICON_BAR_EMPTY='󰼮'                   # Context bar empty segment (Nerd Font, dimmed)
readonly ICON_USAGE_BAR_FILLED='▓'              # Usage bar filled segment (block character)
readonly ICON_USAGE_BAR_EMPTY='░'               # Usage bar empty segment (block character)

################################################################################
# Programming language icons (Nerd Fonts)
################################################################################
readonly ICON_LANG_NODE=""                         # Node.js / JavaScript
readonly ICON_LANG_PYTHON=""                       # Python
readonly ICON_LANG_RUST=""                         # Rust
readonly ICON_LANG_GO=""                           # Go
readonly ICON_LANG_PHP=""                          # PHP
readonly ICON_LANG_JAVA=""                         # Java
readonly ICON_LANG_KOTLIN=""                       # Kotlin
readonly ICON_LANG_C=""                            # C/C++
readonly ICON_LANG_HASKELL=""                      # Haskell

################################################################################
# Verify dependencies
################################################################################
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed" >&2
        exit 1
    fi
}

################################################################################
# Parse JSON input from stdin
################################################################################
parse_input() {
    local input
    input=$(cat)

    # Validate JSON
    if ! echo "$input" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON input" >&2
        exit 1
    fi

    echo "$input"
}

################################################################################
# Detect programming language of the project
################################################################################
detect_language() {
    local dir="${1:-.}"

    # Node.js / JavaScript (highest priority for package.json)
    [[ -f "$dir/package.json" ]] && echo "$ICON_LANG_NODE" && return
    [[ -d "$dir/node_modules" ]] && echo "$ICON_LANG_NODE" && return
    [[ -f "$dir/.nvmrc" ]] && echo "$ICON_LANG_NODE" && return

    # Python
    [[ -f "$dir/requirements.txt" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/pyproject.toml" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/setup.py" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/Pipfile" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/.python-version" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -d "$dir/venv" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -d "$dir/.venv" ]] && echo "$ICON_LANG_PYTHON" && return

    # Rust
    [[ -f "$dir/Cargo.toml" ]] && echo "$ICON_LANG_RUST" && return
    [[ -f "$dir/Cargo.lock" ]] && echo "$ICON_LANG_RUST" && return

    # Go
    [[ -f "$dir/go.mod" ]] && echo "$ICON_LANG_GO" && return
    [[ -f "$dir/go.sum" ]] && echo "$ICON_LANG_GO" && return

    # PHP
    [[ -f "$dir/composer.json" ]] && echo "$ICON_LANG_PHP" && return
    [[ -f "$dir/composer.lock" ]] && echo "$ICON_LANG_PHP" && return

    # Java
    [[ -f "$dir/pom.xml" ]] && echo "$ICON_LANG_JAVA" && return
    [[ -f "$dir/build.gradle" ]] && echo "$ICON_LANG_JAVA" && return

    # Kotlin (check before Java as it might have build.gradle.kts)
    [[ -f "$dir/build.gradle.kts" ]] && echo "$ICON_LANG_KOTLIN" && return
    if compgen -G "$dir/*.kt" > /dev/null 2>&1; then
        echo "$ICON_LANG_KOTLIN" && return
    fi

    # C/C++
    [[ -f "$dir/CMakeLists.txt" ]] && echo "$ICON_LANG_C" && return
    [[ -f "$dir/Makefile" ]] && echo "$ICON_LANG_C" && return
    if compgen -G "$dir/*.[ch]" > /dev/null 2>&1 || compgen -G "$dir/*.cpp" > /dev/null 2>&1; then
        echo "$ICON_LANG_C" && return
    fi

    # Haskell
    [[ -f "$dir/stack.yaml" ]] && echo "$ICON_LANG_HASKELL" && return
    [[ -f "$dir/cabal.project" ]] && echo "$ICON_LANG_HASKELL" && return
    if compgen -G "$dir/*.hs" > /dev/null 2>&1; then
        echo "$ICON_LANG_HASKELL" && return
    fi

    # No language detected
    echo ""
}

################################################################################
# Extract git information with detailed status
################################################################################
get_git_info() {
    # Early return if not in a git repo
    if ! git rev-parse --git-dir &> /dev/null; then
        echo ""
        return
    fi

    # Cache git-dir to avoid multiple calls
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)

    # -------------------------------------------------------------------------
    # Branch detection and special states
    # -------------------------------------------------------------------------
    local branch branch_icon git_color
    branch=$(git branch --show-current 2>/dev/null || echo "")
    git_color="${COLOR_YELLOW}"
    branch_icon="${ICON_GIT_BRANCH}"

    # Handle detached HEAD, rebase, merge states with special coloring
    if [[ -z "$branch" ]]; then
        git_color="${COLOR_ORANGE}"
        branch_icon=""  # Special states include their own icon

        if [[ -d "${git_dir}/rebase-merge" ]] || [[ -d "${git_dir}/rebase-apply" ]]; then
            branch="${ICON_GIT_REBASING} REBASING"
        elif [[ -f "${git_dir}/MERGE_HEAD" ]]; then
            branch="${ICON_GIT_MERGING} MERGING"
        elif [[ -f "${git_dir}/CHERRY_PICK_HEAD" ]]; then
            branch="${ICON_GIT_CHERRY} CHERRY-PICK"
        else
            branch="${ICON_GIT_DETACHED} DETACHED"
        fi
    fi

    # -------------------------------------------------------------------------
    # File status counting
    # -------------------------------------------------------------------------
    local staged=0 modified=0 untracked=0

    while IFS= read -r line; do
        local index_status="${line:0:1}"
        local work_tree_status="${line:1:1}"

        # Count staged files (anything in index that's not space or ?)
        [[ "$index_status" != " " && "$index_status" != "?" ]] && ((staged++))

        # Count modified files (work tree has M or D)
        [[ "$work_tree_status" == "M" || "$work_tree_status" == "D" ]] && ((modified++))

        # Count untracked files
        [[ "$index_status" == "?" && "$work_tree_status" == "?" ]] && ((untracked++))
    done < <(git status --porcelain 2>/dev/null)

    # -------------------------------------------------------------------------
    # Remote tracking (ahead/behind)
    # -------------------------------------------------------------------------
    local ahead=0 behind=0
    local upstream
    upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")

    if [[ -n "$upstream" ]]; then
        local counts
        counts=$(git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null || echo "0	0")
        read -r ahead behind <<< "$counts"
        ahead=${ahead:-0}
        behind=${behind:-0}
    fi

    # -------------------------------------------------------------------------
    # Stash count
    # -------------------------------------------------------------------------
    local stash_count=0
    if git rev-parse --verify refs/stash &>/dev/null; then
        stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    fi

    # -------------------------------------------------------------------------
    # Build status string
    # -------------------------------------------------------------------------
    local status_parts=""
    [[ $staged -gt 0 ]] && status_parts="${status_parts} ${ICON_STAGED}${staged}"
    [[ $modified -gt 0 ]] && status_parts="${status_parts} ${ICON_MODIFIED}${modified}"
    [[ $untracked -gt 0 ]] && status_parts="${status_parts} ${ICON_UNTRACKED}${untracked}"
    [[ $ahead -gt 0 ]] && status_parts="${status_parts} ${ICON_AHEAD}${ahead}"
    [[ $behind -gt 0 ]] && status_parts="${status_parts} ${ICON_BEHIND}${behind}"
    [[ $stash_count -gt 0 ]] && status_parts="${status_parts} ${ICON_STASH}${stash_count}"

    # Return git info with color and content
    echo "${git_color}:${branch_icon}${branch}${status_parts}"
}

################################################################################
# Read usage data from Claude Usage Tracker app (no API calls needed)
################################################################################
fetch_usage_data() {
    # Check if Claude Usage Tracker is configured
    if ! defaults read HamedElfayome.Claude-Usage activeProfileId &>/dev/null; then
        echo "__NOT_INSTALLED__"
        return
    fi

    # Read active profile's cached usage from Claude Usage Tracker defaults
    local profile_json
    profile_json=$(python3 -c "
import subprocess, json, plistlib, sys
result = subprocess.run(['defaults', 'export', 'HamedElfayome.Claude-Usage', '-'],
                       capture_output=True)
if result.returncode != 0:
    sys.exit(1)
plist = plistlib.loads(result.stdout)
profiles = json.loads(plist.get('profiles_v3', b'[]'))
active_id = plist.get('activeProfileId', '')
for p in profiles:
    if p.get('id') == active_id:
        usage = p.get('claudeUsage', {})
        if usage:
            json.dump(usage, sys.stdout)
        break
" 2>/dev/null) || true

    echo "$profile_json"
}

################################################################################
# Format Core Data timestamp to relative time (e.g., 23m, 1h12m)
# Core Data reference date: 2001-01-01 00:00:00 UTC (978307200 unix epoch)
################################################################################
readonly COREDATA_EPOCH_OFFSET=978307200

format_relative_time() {
    local coredata_timestamp="$1"

    # Convert Core Data timestamp to unix epoch
    local target_epoch
    target_epoch=${coredata_timestamp%.*}
    target_epoch=$(( target_epoch + COREDATA_EPOCH_OFFSET ))

    local now_epoch
    now_epoch=$(date +%s)

    local diff=$(( target_epoch - now_epoch ))
    [[ $diff -lt 0 ]] && diff=0

    local hours=$(( diff / 3600 ))
    local minutes=$(( (diff % 3600) / 60 ))

    if [[ $hours -gt 0 ]]; then
        printf '%dh%02dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

################################################################################
# Context bar gradient colors (green -> yellow -> orange -> red)
################################################################################
readonly GRADIENT_COLORS=(
    '\033[38;2;80;250;123m'    # 1: Green (Dracula green #50fa7b)
    '\033[38;2;120;248;100m'   # 2: Green-lime
    '\033[38;2;160;250;85m'    # 3: Lime
    '\033[38;2;200;252;100m'   # 4: Yellow-lime
    '\033[38;2;241;250;140m'   # 5: Yellow (Dracula yellow #f1fa8c)
    '\033[38;2;255;210;100m'   # 6: Yellow-orange
    '\033[38;2;255;184;108m'   # 7: Orange (Dracula orange #ffb86c)
    '\033[38;2;255;140;90m'    # 8: Orange-red
    '\033[38;2;255;100;70m'    # 9: Red-orange
    '\033[38;2;255;85;85m'     # 10: Red (Dracula red #ff5555)
)

################################################################################
# Generate context usage bar with gradient colors
################################################################################
generate_context_bar() {
    local percent="${1:-0}"
    local bar_length=10

    # Calculate filled segments (round to nearest)
    local filled=$(( (percent + 5) / 10 ))  # 0-100% maps to 0-10 segments
    [[ $filled -gt $bar_length ]] && filled=$bar_length
    [[ $filled -lt 0 ]] && filled=0

    # Build the bar with gradient colors for filled, current marker, dim for empty
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${GRADIENT_COLORS[$i]}${ICON_BAR_FILLED}"
    done
    # Current position marker (first empty slot)
    if [[ $filled -lt $bar_length ]]; then
        bar+="${GRADIENT_COLORS[$filled]}${ICON_BAR_CURRENT}"
    fi
    bar+="${COLOR_DIM}"
    for ((i=filled+1; i<bar_length; i++)); do
        bar+="${ICON_BAR_EMPTY}"
    done
    bar+="${COLOR_RESET}"

    printf '%b' "$bar"
}

################################################################################
# Generate usage bar with block characters and gradient colors
################################################################################
generate_usage_bar() {
    local percent="${1:-0}"
    local bar_length=10

    # Calculate filled segments (round to nearest)
    local filled=$(( (percent + 5) / 10 ))
    [[ $filled -gt $bar_length ]] && filled=$bar_length
    [[ $filled -lt 0 ]] && filled=0

    # Build the bar with gradient colors for filled, dim for empty
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="${GRADIENT_COLORS[$i]}${ICON_USAGE_BAR_FILLED}"
    done
    bar+="${COLOR_DIM}"
    for ((i=filled; i<bar_length; i++)); do
        bar+="${ICON_USAGE_BAR_EMPTY}"
    done
    bar+="${COLOR_RESET}"

    printf '%b' "$bar"
}

################################################################################
# Get color for current context percentage
################################################################################
get_percent_color() {
    local percent="${1:-0}"
    # Calculate filled segments (same as generate_context_bar)
    local filled=$(( (percent + 5) / 10 ))
    [[ $filled -gt 10 ]] && filled=10
    [[ $filled -lt 1 ]] && filled=1
    # Use the last filled segment's color (index is filled - 1)
    local index=$((filled - 1))
    printf '%b' "${GRADIENT_COLORS[$index]}"
}

################################################################################
# Format and print the complete status line (3-4 lines)
################################################################################
format_statusline() {
    local folder_name="$1"
    local lang_icon="$2"
    local git_info="$3"
    local model_name="$4"
    local context_percent="$5"
    local usage_data="$6"

    local separator="${COLOR_DIM}─────────────────────────${COLOR_RESET}"

    # Line 1: Folder name with language icon
    local display_icon="${lang_icon:-$ICON_FOLDER}"
    printf "${COLOR_BLUE}${display_icon} %s${COLOR_RESET}\n" "$folder_name"

    # Line 2: Git information
    if [[ -n "$git_info" ]]; then
        local git_color="${git_info%%:*}"
        local git_content="${git_info#*:}"
        printf "${git_color}%s${COLOR_RESET}\n" "$git_content"
    else
        printf "\n"
    fi

    # Middle separator
    printf "%b\n" "$separator"

    # Line 3: AI model name (rainbow via lolcat)
    if command -v lolcat &>/dev/null; then
        echo "${ICON_AI} ${model_name}" | lolcat -f -p 0.2 -S 90
    else
        printf "${COLOR_GREEN}${ICON_AI} %s${COLOR_RESET}\n" "$model_name"
    fi

    # Line 4: Context bar
    local context_bar percent_color
    local percent_int=${context_percent%.*}  # Remove decimal part
    context_bar=$(generate_context_bar "$percent_int")
    percent_color=$(get_percent_color "$percent_int")
    printf "%s %d%%${COLOR_RESET} %s" "$percent_color" "$percent_int" "$context_bar"

    # Line 5: Usage quota from Claude Usage Tracker
    if [[ "$usage_data" == "__NOT_INSTALLED__" ]]; then
        printf "\n${COLOR_DIM}Usage quota requires Claude Usage Tracker"
        printf "\nbrew install claude-usage-tracker${COLOR_RESET}"
    elif [[ -n "$usage_data" ]]; then
        local session_pct session_reset
        session_pct=$(echo "$usage_data" | jq -r '.sessionPercentage // empty' 2>/dev/null) || true
        session_reset=$(echo "$usage_data" | jq -r '.sessionResetTime // empty' 2>/dev/null) || true

        if [[ -n "$session_pct" ]]; then
            local session_int=${session_pct%.*}
            local session_color session_bar reset_time
            session_color=$(get_percent_color "$session_int")
            session_bar=$(generate_usage_bar "$session_int")

            printf "\n"
            printf "%s %d%% %s${COLOR_RESET}" "$session_color" "$session_int" "$session_bar"

            # Reset time (dim)
            if [[ -n "$session_reset" ]]; then
                reset_time=$(format_relative_time "$session_reset")
                if [[ -n "$reset_time" ]]; then
                    printf " ${COLOR_DIM}· %s${COLOR_RESET}" "$reset_time"
                fi
            fi
        fi
    fi

    # Bottom separator
    printf "\n%b" "$separator"
}

################################################################################
# Main execution
################################################################################
main() {
    # Verify dependencies
    check_dependencies

    # Parse and validate JSON input
    local input
    input=$(parse_input)

    # Extract workspace and context information
    local json_output model_name current_dir folder_name context_percent
    json_output=$(echo "$input" | jq -r '[.model.display_name // "Claude", .workspace.current_dir // .cwd // ".", .context_window.used_percentage // 0] | @tsv')
    model_name=$(echo "$json_output" | cut -f1)
    current_dir=$(echo "$json_output" | cut -f2)
    context_percent=$(echo "$json_output" | cut -f3)
    folder_name=$(basename "$current_dir")

    # Detect programming language
    local lang_icon
    lang_icon=$(detect_language "$current_dir")

    # Gather git information
    local git_info
    git_info=$(get_git_info)

    # Read usage data from Claude Usage Tracker
    local usage_data
    usage_data=$(fetch_usage_data 2>/dev/null) || usage_data=""

    # Output formatted status line
    format_statusline "$folder_name" "$lang_icon" "$git_info" "$model_name" "$context_percent" "$usage_data"
}

# Run main function
main
