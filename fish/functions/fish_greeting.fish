# ~/.config/fish/functions/fish_greeting.fish
# Compact welcome banner with rainbow colors via lolcat.

function fish_greeting
    set banner "
󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽-
    Welcome Sergi󰋙 󱑽-
󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽-"

    if type -q lolcat
        echo $banner | lolcat -t --seed=22
    else
        set_color brcyan
        echo $banner
        set_color normal
    end
end
