# List
alias ls='ls -F'
alias la='ls -a'
alias l='ls -l'
alias ll='ls -la'

# Other
alias c="clear"
alias e="exit"
alias h="history"
alias hg="history | grep"
alias ssh="ssh -X"

# navigation
alias .="cd /"
alias ..='cd ..'
alias ..2='cd ../..'
alias ..3='cd ../../..'
alias ..4='cd ../../../..'
alias ..5='cd ../../../../..'

# become root #
alias root='sudo -i'
alias su='sudo -i'


# DISK USAGE
alias du1='du -d 1'

# Grabs the disk usage in the current directory
alias usage='du -ch | grep total'

# Gives you what is using the most space. Both directories and files. Varies on current directory
alias most='du -hsx * | sort -rh | head -10'

