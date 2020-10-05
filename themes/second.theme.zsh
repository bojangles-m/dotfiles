source $THEMES/prompt.zsh

NL=$'\n'
firstLine="[ ${MAGENTA}%~${GREEN}"
firstLine+='$(git_branch)'
firstLine+="${WHITE} ]"
secondLine=" ❯ ${RESET}"

# Set up the prmary prompt (with git branch name)
PROMPT=$NL$firstLine$NL$secondLine

# right prompt
RPROMPT=" ${GREY}%n@%m${RESET}"
