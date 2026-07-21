/opt/homebrew/bin/brew shellenv fish | source

fish_add_path ~/.local/bin

abbr -a n nvim
abbr -a leet 'cd ~/repos/leetcode && nvim .'
abbr -a dev 'kitty @ launch --location=vsplit --cwd=current lazygit && exec claude'

fish_vi_key_bindings

starship init fish | source
zoxide init fish | source
