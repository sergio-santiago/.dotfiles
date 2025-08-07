function fish_greeting
    set greeting "󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽-
       Let's code, Sergi󰋙 󱞤 󱑽󱑽󱑽-
󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽󱑽 󱊾 󱑽-"

    if type -q lolcat
        echo $greeting | lolcat -t -a -i --speed=60 --seed=1998
    else
        set_color brcyan
        echo $greeting
        set_color normal
    end
end
