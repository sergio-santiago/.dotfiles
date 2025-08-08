function rainbow_separator --on-event fish_postexec
    string repeat -n (math (tput cols)) "─" | lolcat -t --spread=1.5
end
