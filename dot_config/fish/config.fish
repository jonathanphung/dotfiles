/opt/homebrew/bin/brew shellenv fish | source

fish_add_path ~/.local/bin

abbr -a n nvim
abbr -a leet 'cd ~/repos/leetcode && nvim .'

fish_vi_key_bindings

starship init fish | source
zoxide init fish | source
