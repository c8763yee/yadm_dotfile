# pacman aliases
alias pS='sudo pacman -S --needed'
alias pR='sudo pacman -R'
alias pSyu='sudo pacman -Syu --needed'
alias yS='yay -S --needed'
alias yR='yay -R'
alias ySyu='yay -Syu --needed'

# neovim aliases
alias vim=nvim
alias svim="sudo -E nvim"

# ssh aliases
alias sshPWno='sudo sed -i "s/^PasswordAuthentication yes$/PasswordAuthentication no/1" /etc/ssh/sshd_config && sudo systemctl restart sshd'
alias sshPWyes='sudo sed -i "s/^PasswordAuthentication no$/PasswordAuthentication yes/1" /etc/ssh/sshd_config && sudo systemctl restart sshd'

# yadm aliases
alias y='yadm'

# supervisorctl aliases
alias ssu='sudo supervisorctl'
alias ssr='sudo systemctl'
alias sru='systemctl --user'
