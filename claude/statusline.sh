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
# Color definitions (RGB format)
################################################################################
readonly COLOR_SAPPHIRE='\033[38;2;104;213;255m'    # Folder name
readonly COLOR_YELLOW='\033[38;2;255;236;153m'      # Git branch/status
readonly COLOR_GREEN='\033[38;2;61;252;110m'        # Model name
readonly COLOR_ORANGE='\033[38;2;255;184;108m'      # Special states (rebase, merge, etc)
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
        counts=$(git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null || echo "0 0")
        ahead=${counts%% *}
        behind=${counts##* }
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
# Format and print the complete status line (3 lines)
################################################################################
format_statusline() {
    local folder_name="$1"
    local lang_icon="$2"
    local git_info="$3"
    local model_name="$4"

    # Line 1: Folder name with language icon
    local display_icon="${lang_icon:-$ICON_FOLDER}"
    printf "${COLOR_SAPPHIRE}${display_icon} %s${COLOR_RESET}\n" "$folder_name"

    # Line 2: Git information
    if [[ -n "$git_info" ]]; then
        local git_color="${git_info%%:*}"
        local git_content="${git_info#*:}"
        printf "${git_color}%s${COLOR_RESET}\n" "$git_content"
    else
        printf "\n"
    fi

    # Line 3: AI model name
    printf "${COLOR_GREEN}${ICON_AI} %s${COLOR_RESET}" "$model_name"
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

    # Extract workspace information
    local json_output model_name current_dir folder_name
    json_output=$(echo "$input" | jq -r '[.model.display_name // "Claude", .workspace.current_dir // .cwd // "."] | @tsv')
    model_name=$(echo "$json_output" | cut -f1)
    current_dir=$(echo "$json_output" | cut -f2)
    folder_name=$(basename "$current_dir")

    # Detect programming language
    local lang_icon
    lang_icon=$(detect_language "$current_dir")

    # Gather git information
    local git_info
    git_info=$(get_git_info)

    # Output formatted status line
    format_statusline "$folder_name" "$lang_icon" "$git_info" "$model_name"
}

# Run main function
main
