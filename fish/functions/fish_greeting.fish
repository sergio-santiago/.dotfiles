# ~/.config/fish/functions/fish_greeting.fish
# Custom Fish shell greeting displayed at shell startup.
# Replaces the default `Welcome to fish` message with a personalized, icon-rich banner.
# If `lolcat` is available, the greeting is shown with animated rainbow colors;
# otherwise, it falls back to static bright cyan text.

function fish_greeting
    set greeting "󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽-
     Let's code Sergi󰋙    󱞤 󱑽󱑽󱑽-
󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽 󱊾 󱑽-"

    if type -q lolcat
        echo $greeting | lolcat -t -a -i --speed=60 --seed=1998
    else
        set_color brcyan
        echo $greeting
        set_color normal
    end
end
