source $THEMES/prompt.zsh

# Set up the prmary prompt (with git branch name)
setopt PROMPT_SUBST

NL=$'\n'
firstLine="[ ${MAGENTA}%~${GREEN}"
firstLine+='$(git_branch)'
firstLine+="${WHITE} ]"
secondLine=" ❯ ${RESET}"

PROMPT=$NL$firstLine$NL$secondLine

# right prompt
RPROMPT=" ${GREY}%n@%m${RESET}"
