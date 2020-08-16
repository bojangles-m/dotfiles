# ------------------------------------
# Git branch presentation in promt
# ------------------------------------
# Load version control information
function git_branch() {
    # Speed up opening up a new terminal tab by not
    # checking $HOME... which can't be a repo anyway
    [ "$PWD" = "$HOME" ] && return

    # Fastest way I know to check the current branch name
    branch="$(command git symbolic-ref --short HEAD 2> /dev/null)" || return
    echo " ($branch)"
}

# ------------------------------------
# PROMPT setup
# ------------------------------------

# specifies how to color specific items
export LSCOLORS=cxGxcxdxbxegedabagaced

# enables coloring of terminal
export CLICOLOR=1

# setting up colors
autoload -U colors && colors
for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
    eval $COLOR='%{$fg_no_bold[${(L)COLOR}]%}'  #wrap colours between %{ %} to avoid weird gaps in autocomplete
    eval BOLD_$COLOR='%{$fg_bold[${(L)COLOR}]%}'
done
eval RESET='%{$reset_color%}'

# coloring the Prompt in zsh
NL=$'\n'
firstLine="[%n${YELLOW}@${RED} %m ${WHITE}: ${MAGENTA}%~${GREEN}"
firstLine+='$(git_branch)'
firstLine+="${WHITE}]${RESET}"
secondLine="${WHITE} ❯ ${RESET}"

# Set up the prompt (with git branch name)
setopt PROMPT_SUBST
PROMPT=$NL$firstLine$NL$secondLine