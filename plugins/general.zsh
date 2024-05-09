# List
alias ls='ls -F'
alias la='ls -a'
alias l='ls -l'
alias ll='ls -la'

# misc
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
alias da='sudo du -sch'
alias du1='sudo du -d 1'

# Grabs the disk usage in the current directory
alias usage='sudo du -ch | grep total'

# Gives you what is using the most space. Both directories and files. Varies on current directory
alias most='sudo du -hsx * | sort -rh | head -10'

