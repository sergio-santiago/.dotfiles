# ~/.config/fish/functions/banner_sergio.fish
# Custom ASCII banner for Fish shell startup.
# Displays either a large decorative ASCII art banner ("full" mode)
# or a minimal compact version, depending on terminal width or user setting.
# Supports colorized output via `lolcat` if installed; falls back to cyan text otherwise.
#
# Behavior:
#   - Mode is controlled by $BANNER_MODE environment variable:
#       full    → always show the full-width ASCII banner
#       compact → always show the compact banner
#       auto    → choose based on terminal width (default)
#   - Terminal width threshold: 130 columns for full banner.
#   - `lolcat` adds rainbow animation; without it, prints in bright cyan.

function banner_sergio
    # Get current terminal width (columns)
    set cols (tput cols)
    set min_width 130  # Minimum columns required for full banner in auto mode

    # Determine mode from env var (full | compact | auto), default: auto
    set banner_mode (set -q BANNER_MODE; and echo $BANNER_MODE; or echo "auto")

    # Full-width ASCII banner text
    set full_banner_text "
            ____         ╔════════════════════════════════════════════════════════════════════════════════════╗         ____         
           /    \        ║          _            _            _           _               _          _        ║        /    \        
      ____/      \____   ║         / /\         /\ \         /\ \        /\ \            /\ \       /\ \      ║   ____/      \____   
     /    \      /    \  ║        / /  \       /  \ \       /  \ \      /  \ \           \ \ \     /  \ \     ║  /    \      /    \  
    /      \____/      \ ║       / / /\ \__   / /\ \ \     / /\ \ \    / /\ \_\          /\ \_\   / /\ \ \    ║ /      \____/      \ 
    \      /    \      / ║      / / /\ \___\ / / /\ \_\   / / /\ \_\  / / /\/_/         / /\/_/  / / /\ \ \   ║ \      /    \      / 
     \____/      \____/  ║      \ \ \ \/___// /_/_ \/_/  / / /_/ / / / / / ______      / / /    / / /  \ \_\  ║  \____/      \____/  
     /    \      /    \  ║       \ \ \     / /____/\    / / /__\/ / / / / /\_____\    / / /    / / /   / / /  ║  /    \      /    \  
    /      \____/      \ ║   _    \ \ \   / /\____\/   / / /_____/ / / /  \/____ /   / / /    / / /   / / /   ║ /      \____/      \ 
    \      /    \      / ║  /_/\__/ / /  / / /______  / / /\ \ \  / / /_____/ / /___/ / /__  / / /___/ / /    ║ \      /    \      / 
     \____/      \____/  ║  \ \/___/ /  / / /_______\/ / /  \ \ \/ / /______\/ //\__\/_/___\/ / /____\/ /     ║  \____/      \____/  
          \      /       ║   \_____\/   \/__________/\/_/    \_\/\/___________/ \/_________/\/_________/      ║       \      /       
           \____/        ║                                                                                    ║        \____/        
                         ╚════════════════════════════════════════════════════════════════════════════════════╝
                                               ╔════════════════════════════════════════╗
                                               ║         Welcome to Terminal!          ║
                                               ╚════════════════════════════════════════╝
    "

    # Compact fallback banner (shown when terminal is narrow or in compact mode)
    set compact_banner_text "
╔═══════════════════════════════════╗
║      Welcome to Terminal!        ║
╚═══════════════════════════════════╝
    "

    # Decide which banner to show based on mode and terminal width
    switch $banner_mode
        case full
            set show_full true
        case compact
            set show_full false
        case auto
            set show_full (test "$cols" -ge "$min_width"; and echo true; or echo false)
    end

    # Print the chosen banner with colors if possible
    if test "$show_full" = "true"
        if type -q lolcat
            echo "$full_banner_text" | lolcat -t
        else
            set_color brcyan
            echo "$full_banner_text"
            set_color normal
        end
    else
        if type -q lolcat
            echo "$compact_banner_text" | lolcat -t
        else
            set_color brcyan
            echo "$compact_banner_text"
            set_color normal
        end
    end
end
