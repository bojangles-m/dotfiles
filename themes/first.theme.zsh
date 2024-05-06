source $THEMES/prompt.zsh

# coloring the Prompt in zsh
NL=$'\n'
firstLine="[%n${YELLOW}@${RED}%m ${WHITE}: ${MAGENTA}%~${GREEN}"
firstLine+='$(getGitBranchName)'
firstLine+="${WHITE}]${RESET}"
secondLine="${WHITE} ❯ ${RESET}"

# Set up the prmary prompt (with git branch name)
PS1=$NL$firstLine$NL$secondLine
