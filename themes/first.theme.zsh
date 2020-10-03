source $THEMES/prompt.zsh

# coloring the Prompt in zsh
NL=$'\n'
firstLine="[%n${YELLOW}@${RED}%m ${WHITE}: ${MAGENTA}%~${GREEN}"
firstLine+='$(git_branch)'
firstLine+="${WHITE}]${RESET}"
secondLine="${WHITE} ❯ ${RESET}"

# Set up the prmary prompt (with git branch name)
setopt PROMPT_SUBST
PS1=$NL$firstLine$NL$secondLine
