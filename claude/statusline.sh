#!/bin/bash
################################################################################
# Claude Code Status Line Generator
#
# Description:
#   Generates a responsive 2-column boxed statusline showing:
#     Left column:  folder, git branch+status, diff stats (+added / -deleted)
#     Right column: AI model, context bar + zone tag, usage bar + reset time
#
#   Column widths auto-fit the longest cell on each side (responsive layout).
#   The middle │ stays vertically aligned regardless of content length.
#
# Input (via stdin):
#   JSON object matching Claude Code statusLine schema.
#   Fields consumed (all native, no external trackers):
#     .model.display_name                        → model name
#     .workspace.current_dir  (fallback .cwd)    → folder
#     .context_window.used_percentage            → context bar %
#     .rate_limits.five_hour.used_percentage     → usage bar %
#     .rate_limits.five_hour.resets_at           → reset countdown
#
# Context zones (thresholds sourced from Claude Code community data):
#   <20% fresh · 20-50% warm · 50-60% heavy · 60%+ compact!
#
# Output:
#   5-line table with ANSI colors:
#     ──────────────┬───────────────────────────╮
#      folder        │ 󰧑 Model                    │
#      branch        │ ctx% context-bar 󰖙 zone   │
#     N+ 󰓢 -N        │ use% usage-bar 󱎫 reset    │
#     ──────────────┴───────────────────────────╯
#
# External dependencies: jq, python3 (both typically pre-installed on macOS).
################################################################################

set -euo pipefail

################################################################################
# Color definitions (real ESC bytes via $'...')
################################################################################
readonly COLOR_BLUE=$'\033[38;2;104;213;255m'     # Folder name
readonly COLOR_CYAN=$'\033[38;2;127;255;212m'     # Fresh context zone (matches starship docker)
readonly COLOR_YELLOW=$'\033[38;2;255;236;153m'   # Git branch (normal)
readonly COLOR_ORANGE=$'\033[38;2;255;184;108m'   # Git special states
readonly COLOR_GREEN=$'\033[38;2;68;243;115m'     # Added lines / fallback model
readonly COLOR_PURPLE=$'\033[38;2;189;147;249m'   # Clock icon
readonly COLOR_RED=$'\033[38;2;255;85;85m'        # Deleted lines
readonly COLOR_DIM=$'\033[38;2;108;108;108m'      # Borders, placeholders
readonly COLOR_DIM_BRIGHT=$'\033[38;2;170;170;170m' # Diff arrows when changes present
readonly COLOR_RESET=$'\033[0m'

################################################################################
# Icon definitions (Nerd Fonts)
################################################################################
readonly ICON_FOLDER=""
readonly ICON_GIT_BRANCH=" "
readonly ICON_GIT_REBASING=""
readonly ICON_GIT_MERGING=""
readonly ICON_GIT_CHERRY=""
readonly ICON_GIT_DETACHED="󰃻"
readonly ICON_AI="󰧑"
readonly ICON_STAGED="+"
readonly ICON_MODIFIED="!"
readonly ICON_UNTRACKED="?"
readonly ICON_AHEAD="⇡"
readonly ICON_BEHIND="⇣"
readonly ICON_STASH="$"
readonly ICON_BAR_FILLED='󱑽'
readonly ICON_BAR_CURRENT=''
readonly ICON_BAR_EMPTY='󰼮'
readonly ICON_USAGE_BAR_FILLED='▓'
readonly ICON_USAGE_BAR_EMPTY='░'
readonly ICON_DIFF_ARROWS='󰓢'
readonly ICON_DIFF_SIGN=''
readonly ICON_CLOCK='󱎫'
readonly ICON_ZONE_FRESH='󰜗'
readonly ICON_ZONE_WARM='󰖙'
readonly ICON_ZONE_HEAVY='󱗗'
readonly ICON_ZONE_COMPACT='󰚌'

readonly ICON_SEPARATOR_LINE='─'
readonly ICON_SEPARATOR_T_TOP='┬'
readonly ICON_SEPARATOR_T_BOTTOM='┴'
readonly ICON_SEPARATOR_TOP_RIGHT='╮'
readonly ICON_SEPARATOR_BOTTOM_RIGHT='╯'
readonly ICON_VBAR='│'

################################################################################
# Programming language icons (Nerd Fonts)
################################################################################
readonly ICON_LANG_NODE=""
readonly ICON_LANG_PYTHON=""
readonly ICON_LANG_RUST=""
readonly ICON_LANG_GO=""
readonly ICON_LANG_PHP=""
readonly ICON_LANG_JAVA=""
readonly ICON_LANG_KOTLIN=""
readonly ICON_LANG_C=""
readonly ICON_LANG_HASKELL=""

################################################################################
# Context/usage bar gradient colors (green -> yellow -> orange -> red)
################################################################################
readonly GRADIENT_COLORS=(
    $'\033[38;2;80;250;123m'    # 1: Green (Dracula green #50fa7b)
    $'\033[38;2;120;248;100m'   # 2: Green-lime
    $'\033[38;2;160;250;85m'    # 3: Lime
    $'\033[38;2;200;252;100m'   # 4: Yellow-lime
    $'\033[38;2;241;250;140m'   # 5: Yellow (Dracula yellow #f1fa8c)
    $'\033[38;2;255;210;100m'   # 6: Yellow-orange
    $'\033[38;2;255;184;108m'   # 7: Orange (Dracula orange #ffb86c)
    $'\033[38;2;255;140;90m'    # 8: Orange-red
    $'\033[38;2;255;100;70m'    # 9: Red-orange
    $'\033[38;2;255;85;85m'     # 10: Red (Dracula red #ff5555)
)

################################################################################
# Verify dependencies (jq for JSON parsing, python3 for column layout)
################################################################################
check_dependencies() {
    local missing=()
    command -v jq      &>/dev/null || missing+=("jq")
    command -v python3 &>/dev/null || missing+=("python3")
    if (( ${#missing[@]} > 0 )); then
        echo "Error: missing required dependencies: ${missing[*]}" >&2
        exit 1
    fi
}

################################################################################
# Parse JSON input from stdin
################################################################################
parse_input() {
    local input
    input=$(cat)
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

    [[ -f "$dir/package.json" ]] && echo "$ICON_LANG_NODE" && return
    [[ -d "$dir/node_modules" ]] && echo "$ICON_LANG_NODE" && return
    [[ -f "$dir/.nvmrc" ]] && echo "$ICON_LANG_NODE" && return

    [[ -f "$dir/requirements.txt" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/pyproject.toml" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/setup.py" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/Pipfile" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -f "$dir/.python-version" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -d "$dir/venv" ]] && echo "$ICON_LANG_PYTHON" && return
    [[ -d "$dir/.venv" ]] && echo "$ICON_LANG_PYTHON" && return

    [[ -f "$dir/Cargo.toml" ]] && echo "$ICON_LANG_RUST" && return
    [[ -f "$dir/Cargo.lock" ]] && echo "$ICON_LANG_RUST" && return

    [[ -f "$dir/go.mod" ]] && echo "$ICON_LANG_GO" && return
    [[ -f "$dir/go.sum" ]] && echo "$ICON_LANG_GO" && return

    [[ -f "$dir/composer.json" ]] && echo "$ICON_LANG_PHP" && return
    [[ -f "$dir/composer.lock" ]] && echo "$ICON_LANG_PHP" && return

    [[ -f "$dir/pom.xml" ]] && echo "$ICON_LANG_JAVA" && return
    [[ -f "$dir/build.gradle" ]] && echo "$ICON_LANG_JAVA" && return

    [[ -f "$dir/build.gradle.kts" ]] && echo "$ICON_LANG_KOTLIN" && return
    if compgen -G "$dir/*.kt" > /dev/null 2>&1; then
        echo "$ICON_LANG_KOTLIN" && return
    fi

    [[ -f "$dir/CMakeLists.txt" ]] && echo "$ICON_LANG_C" && return
    [[ -f "$dir/Makefile" ]] && echo "$ICON_LANG_C" && return
    if compgen -G "$dir/*.[ch]" > /dev/null 2>&1 || compgen -G "$dir/*.cpp" > /dev/null 2>&1; then
        echo "$ICON_LANG_C" && return
    fi

    [[ -f "$dir/stack.yaml" ]] && echo "$ICON_LANG_HASKELL" && return
    [[ -f "$dir/cabal.project" ]] && echo "$ICON_LANG_HASKELL" && return
    if compgen -G "$dir/*.hs" > /dev/null 2>&1; then
        echo "$ICON_LANG_HASKELL" && return
    fi

    echo ""
}

################################################################################
# Extract git information with detailed status
# Output format: "{color}:{content}" (colon-separated)
################################################################################
get_git_info() {
    if ! git rev-parse --git-dir &> /dev/null; then
        echo ""
        return
    fi

    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)

    local branch branch_icon git_color
    branch=$(git branch --show-current 2>/dev/null || echo "")
    git_color="${COLOR_YELLOW}"
    branch_icon="${ICON_GIT_BRANCH}"

    if [[ -z "$branch" ]]; then
        git_color="${COLOR_ORANGE}"
        branch_icon=""
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

    local staged=0 modified=0 untracked=0
    while IFS= read -r line; do
        local index_status="${line:0:1}"
        local work_tree_status="${line:1:1}"
        [[ "$index_status" != " " && "$index_status" != "?" ]] && ((staged++))
        [[ "$work_tree_status" == "M" || "$work_tree_status" == "D" ]] && ((modified++))
        [[ "$index_status" == "?" && "$work_tree_status" == "?" ]] && ((untracked++))
    done < <(git status --porcelain 2>/dev/null)

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

    local stash_count=0
    if git rev-parse --verify refs/stash &>/dev/null; then
        stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    fi

    local status_parts=""
    [[ $staged -gt 0 ]] && status_parts="${status_parts} ${ICON_STAGED}${staged}"
    [[ $modified -gt 0 ]] && status_parts="${status_parts} ${ICON_MODIFIED}${modified}"
    [[ $untracked -gt 0 ]] && status_parts="${status_parts} ${ICON_UNTRACKED}${untracked}"
    [[ $ahead -gt 0 ]] && status_parts="${status_parts} ${ICON_AHEAD}${ahead}"
    [[ $behind -gt 0 ]] && status_parts="${status_parts} ${ICON_BEHIND}${behind}"
    [[ $stash_count -gt 0 ]] && status_parts="${status_parts} ${ICON_STASH}${stash_count}"

    echo "${git_color}:${branch_icon}${branch}${status_parts}"
}

################################################################################
# Get diff stats vs HEAD (staged + unstaged combined)
# Output: "added:deleted"
################################################################################
get_diff_stats() {
    local added=0 deleted=0
    if git rev-parse --git-dir &>/dev/null; then
        local stats
        stats=$(git diff HEAD --shortstat 2>/dev/null || true)
        if [[ -n "$stats" ]]; then
            if [[ "$stats" =~ ([0-9]+)[[:space:]]+insertion ]]; then
                added="${BASH_REMATCH[1]}"
            fi
            if [[ "$stats" =~ ([0-9]+)[[:space:]]+deletion ]]; then
                deleted="${BASH_REMATCH[1]}"
            fi
        fi
    fi
    echo "${added}:${deleted}"
}

################################################################################
# Format Unix epoch timestamp to relative time (e.g. 23m, 1h12m)
################################################################################
format_relative_time() {
    local target_epoch="${1%.*}"

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
# Generate context usage bar with gradient colors
################################################################################
generate_context_bar() {
    local percent="${1:-0}"
    local bar_length=10
    local filled=$(( (percent * bar_length + 50) / 100 ))
    [[ $filled -gt $bar_length ]] && filled=$bar_length
    [[ $filled -lt 0 ]] && filled=0

    local bar=""
    local i color_idx
    for ((i=0; i<filled; i++)); do
        color_idx=$(( i * 10 / bar_length ))
        bar+="${GRADIENT_COLORS[$color_idx]}${ICON_BAR_FILLED}"
    done
    if [[ $filled -lt $bar_length ]]; then
        color_idx=$(( filled * 10 / bar_length ))
        [[ $color_idx -gt 9 ]] && color_idx=9
        bar+="${GRADIENT_COLORS[$color_idx]}${ICON_BAR_CURRENT}"
    fi
    bar+="${COLOR_DIM}"
    for ((i=filled+1; i<bar_length; i++)); do
        bar+="${ICON_BAR_EMPTY}"
    done
    bar+="${COLOR_RESET}"
    printf '%s' "$bar"
}

################################################################################
# Generate usage bar with block characters
################################################################################
generate_usage_bar() {
    local percent="${1:-0}"
    local bar_length=10
    local filled=$(( (percent + 5) / 10 ))
    [[ $filled -gt $bar_length ]] && filled=$bar_length
    [[ $filled -lt 0 ]] && filled=0

    local bar=""
    local i
    for ((i=0; i<filled; i++)); do
        bar+="${GRADIENT_COLORS[$i]}${ICON_USAGE_BAR_FILLED}"
    done
    bar+="${COLOR_DIM}"
    for ((i=filled; i<bar_length; i++)); do
        bar+="${ICON_USAGE_BAR_EMPTY}"
    done
    bar+="${COLOR_RESET}"
    printf '%s' "$bar"
}

################################################################################
# Get color for current percentage
################################################################################
get_percent_color() {
    local percent="${1:-0}"
    local filled=$(( (percent + 5) / 10 ))
    [[ $filled -gt 10 ]] && filled=10
    [[ $filled -lt 1 ]] && filled=1
    local index=$((filled - 1))
    printf '%s' "${GRADIENT_COLORS[$index]}"
}

################################################################################
# Format a 2-digit percentage. If value < 10, the leading "0" is dimmed.
################################################################################
format_percent() {
    local value="$1"
    local color="$2"
    if (( value < 10 )); then
        printf '%s0%s%d%%%s' "$COLOR_DIM" "$color" "$value" "$COLOR_RESET"
    else
        printf '%s%d%%%s' "$color" "$value" "$COLOR_RESET"
    fi
}

################################################################################
# Build the diff stats cell: "N+ 󰓢 -N" with + and - sides colored when nonzero
################################################################################
build_diff_cell() {
    local added="$1"
    local deleted="$2"
    local added_color="$COLOR_DIM"
    local deleted_color="$COLOR_DIM"
    local arrows_color="$COLOR_DIM"
    [[ "$added" -gt 0 ]] && added_color="$COLOR_GREEN"
    [[ "$deleted" -gt 0 ]] && deleted_color="$COLOR_RED"
    (( added > 0 || deleted > 0 )) && arrows_color="$COLOR_DIM_BRIGHT"
    printf '%s%d+%s%s%s%s%s%s%s-%d%s' \
        "$added_color" "$added" "$ICON_DIFF_SIGN" "$COLOR_RESET" \
        "$arrows_color" "$ICON_DIFF_ARROWS" "$COLOR_RESET" \
        "$deleted_color" "$ICON_DIFF_SIGN" "$deleted" "$COLOR_RESET"
}

################################################################################
# Lay out 6 cells (3 left, 3 right) in a responsive 2-column box.
# Args: $1..$3 left rows, $4..$6 right rows (each may contain ANSI escapes).
# Computes visible widths via Python and aligns the dividing │ vertically.
################################################################################
layout_two_columns() {
    DIM_COLOR="$COLOR_DIM" \
    RESET_COLOR="$COLOR_RESET" \
    SEP_LINE="$ICON_SEPARATOR_LINE" \
    SEP_T_TOP="$ICON_SEPARATOR_T_TOP" \
    SEP_T_BOTTOM="$ICON_SEPARATOR_T_BOTTOM" \
    SEP_TOP_RIGHT="$ICON_SEPARATOR_TOP_RIGHT" \
    SEP_BOTTOM_RIGHT="$ICON_SEPARATOR_BOTTOM_RIGHT" \
    VBAR="$ICON_VBAR" \
    python3 - "$@" <<'PYEOF'
import os, re, sys, unicodedata

ANSI = re.compile(r'\x1b\[[0-9;]*m')

def vwidth(s: str) -> int:
    """Visible cell width, ignoring ANSI escapes. Treats Nerd-Font PUA as 1 cell."""
    s = ANSI.sub('', s)
    w = 0
    for ch in s:
        cp = ord(ch)
        if cp < 0x20:
            continue
        # Nerd Fonts BMP PUA + Supplementary PUA — single-cell in Nerd Fonts
        if 0xE000 <= cp <= 0xF8FF or 0xF0000 <= cp <= 0x10FFFD:
            w += 1
            continue
        ea = unicodedata.east_asian_width(ch)
        w += 2 if ea in ('W', 'F') else 1
    return w

DIM = os.environ['DIM_COLOR']
RESET = os.environ['RESET_COLOR']
SEP = os.environ['SEP_LINE']
T_TOP = os.environ['SEP_T_TOP']
T_BOT = os.environ['SEP_T_BOTTOM']
TR = os.environ['SEP_TOP_RIGHT']
BR = os.environ['SEP_BOTTOM_RIGHT']
VBAR = os.environ['VBAR']

cells = sys.argv[1:7]
left  = cells[:3]
right = cells[3:]
lw = [vwidth(c) for c in left]
rw = [vwidth(c) for c in right]
lmax = max(lw) if lw else 0
rmax = max(rw) if rw else 0

# Inside-cell padding: 3 leading + content + 1 trailing  (left)
#                     1 leading + content + 1 trailing  (right)
LEFT_LPAD, LEFT_RPAD  = 3, 1
RIGHT_LPAD, RIGHT_RPAD = 1, 1

# Visual trim for the separator line — terminal renders box-drawing chars
# slightly wider than the cell padding suggests, so shave a few chars off
# the dashes to land the ┬/┴ underneath the content's │.
LEFT_SEP_TRIM = 3
RIGHT_SEP_TRIM = 0

left_inner  = LEFT_LPAD + lmax + LEFT_RPAD
right_inner = RIGHT_LPAD + rmax + RIGHT_RPAD

left_sep  = SEP * max(0, left_inner - LEFT_SEP_TRIM)
right_sep = SEP * max(0, right_inner - RIGHT_SEP_TRIM)

top    = f"{DIM}{left_sep}{T_TOP}{right_sep}{TR}{RESET}"
bottom = f"{DIM}{left_sep}{T_BOT}{right_sep}{BR}{RESET}"

print(top)
for i in range(3):
    lc, rc = left[i], right[i]
    lpad = ' ' * (lmax - lw[i])
    rpad = ' ' * (rmax - rw[i])
    line = (
        ' ' * LEFT_LPAD + lc + lpad + ' ' * LEFT_RPAD
        + f"{DIM}{VBAR}{RESET}"
        + ' ' * RIGHT_LPAD + rc + rpad + ' ' * RIGHT_RPAD
        + f"{DIM}{VBAR}{RESET}"
    )
    print(line)
sys.stdout.write(bottom)
PYEOF
}

################################################################################
# Build right-column cell #3: usage % + bar + reset time
################################################################################
build_usage_cell() {
    local session_pct="$1"
    local session_reset="$2"

    if [[ -z "$session_pct" ]]; then
        printf '%sno usage data yet%s' "$COLOR_DIM" "$COLOR_RESET"
        return
    fi

    local session_int=${session_pct%.*}
    session_int=${session_int:-0}

    local session_color session_bar
    session_color=$(get_percent_color "$session_int")
    session_bar=$(generate_usage_bar "$session_int")

    printf '%s %s' "$(format_percent "$session_int" "$session_color")" "$session_bar"

    if [[ -n "$session_reset" ]]; then
        local reset_time
        reset_time=$(format_relative_time "$session_reset")
        if [[ -n "$reset_time" ]]; then
            printf ' %s%s %s%s' "$COLOR_PURPLE" "$ICON_CLOCK" "$reset_time" "$COLOR_RESET"
        fi
    fi
}

################################################################################
# Format and print the complete status line as a 2-column responsive box
################################################################################
format_statusline() {
    local folder_name="$1"
    local lang_icon="$2"
    local git_info="$3"
    local model_name="$4"
    local context_percent="$5"
    local session_pct="$6"
    local session_reset="$7"
    local diff_stats="$8"

    local diff_added="${diff_stats%%:*}"
    local diff_deleted="${diff_stats#*:}"
    local percent_int=${context_percent%.*}
    percent_int=${percent_int:-0}

    # ─────── LEFT COLUMN ───────
    local display_icon="${lang_icon:-$ICON_FOLDER}"
    local left_1
    left_1=$(printf '%s%s %s%s' "$COLOR_BLUE" "$display_icon" "$folder_name" "$COLOR_RESET")

    local left_2
    if [[ -n "$git_info" ]]; then
        local git_color="${git_info%%:*}"
        local git_content="${git_info#*:}"
        left_2=$(printf '%s%s%s' "$git_color" "$git_content" "$COLOR_RESET")
    else
        left_2=$(printf '%s%suntracked%s' "$COLOR_DIM" "$ICON_GIT_BRANCH" "$COLOR_RESET")
    fi

    local left_3
    left_3=$(build_diff_cell "$diff_added" "$diff_deleted")

    # ─────── RIGHT COLUMN ───────
    local right_1
    if command -v lolcat &>/dev/null; then
        right_1=$(printf '%s %s' "$ICON_AI" "$model_name" | lolcat -f -p 0.2 -S 90)
    else
        right_1=$(printf '%s%s %s%s' "$COLOR_GREEN" "$ICON_AI" "$model_name" "$COLOR_RESET")
    fi

    local context_bar percent_color
    context_bar=$(generate_context_bar "$percent_int")
    percent_color=$(get_percent_color "$percent_int")
    local right_2
    right_2=$(printf '%s %s' "$(format_percent "$percent_int" "$percent_color")" "$context_bar")

    local zone_icon zone_text zone_color
    if   (( percent_int < 20 )); then zone_icon="$ICON_ZONE_FRESH";   zone_text="fresh";    zone_color="$COLOR_CYAN"
    elif (( percent_int < 50 )); then zone_icon="$ICON_ZONE_WARM";    zone_text="warm";     zone_color="$COLOR_YELLOW"
    elif (( percent_int < 60 )); then zone_icon="$ICON_ZONE_HEAVY";   zone_text="heavy";    zone_color="$COLOR_ORANGE"
    else                              zone_icon="$ICON_ZONE_COMPACT"; zone_text="compact!"; zone_color="$COLOR_RED"
    fi
    right_2+=$(printf ' %s%s %s%s' "$zone_color" "$zone_icon" "$zone_text" "$COLOR_RESET")

    local right_3
    right_3=$(build_usage_cell "$session_pct" "$session_reset")

    layout_two_columns "$left_1" "$left_2" "$left_3" "$right_1" "$right_2" "$right_3"
}

################################################################################
# Main execution
################################################################################
main() {
    check_dependencies

    local input
    input=$(parse_input)

    local json_output model_name current_dir folder_name context_percent session_pct session_reset
    json_output=$(echo "$input" | jq -r '[
        .model.display_name // "Claude",
        .workspace.current_dir // .cwd // ".",
        .context_window.used_percentage // 0,
        .rate_limits.five_hour.used_percentage // "",
        .rate_limits.five_hour.resets_at // ""
    ] | @tsv')
    model_name=$(echo "$json_output" | cut -f1)
    current_dir=$(echo "$json_output" | cut -f2)
    context_percent=$(echo "$json_output" | cut -f3)
    session_pct=$(echo "$json_output" | cut -f4)
    session_reset=$(echo "$json_output" | cut -f5)
    folder_name=$(basename "$current_dir")

    local lang_icon
    lang_icon=$(detect_language "$current_dir")

    local git_info
    git_info=$(get_git_info)

    local diff_stats
    diff_stats=$(get_diff_stats)

    format_statusline "$folder_name" "$lang_icon" "$git_info" "$model_name" "$context_percent" "$session_pct" "$session_reset" "$diff_stats"
}

main
