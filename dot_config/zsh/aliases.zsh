# Better ls
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons'
compdef eza=ls

# Better cat
alias cat='bat'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'
alias python='python3'
alias cli50='command cli50 -d "$HOME/.ssh" -d "$HOME/.inputrc"'

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

# =========================================================
# Editor
# =========================================================

alias vim='nvim'

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'

# =========================================================
# Personal
# =========================================================

alias n="nvim"
alias leet="cd ~/repos/leetcode && yazi"
alias learnvim="cd ~/.vscode/extensions/vintharas.learn-vim-0.0.28/exercises && yazi"
alias dev="kitty @ launch --location=vsplit --cwd=current lazygit && exec claude"
