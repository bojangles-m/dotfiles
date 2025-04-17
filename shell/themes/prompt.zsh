function getRandomSymbol() {
    typeset -A LIST_OF_SYMBOLS
    LIST_OF_SYMBOLS=(scissors "✂️" popcorn "\U1F37F" doughnut "\U1F369" tada "\U1F389" cake "\U1F370" beer "\U1F37A" beers "\U1F37B" santa "\U1F385" shrimp "\U1F364" sushi "\U1F363" waterMelon "\U1F349" downArrowStrong "\U2B07" apple "\U1F34E" bowAndArrow "\U1F3F9" upArrowStrong "\U2B06" hotdog "\U1F32D" tacos "\U1F32E" palm "\U1F334" corn "\U1F33D")
    LIST_OF_KEYS=($(for key value in "${(@kv)LIST_OF_SYMBOLS}"; do echo "$key"; done))

    MAX=${#LIST_OF_SYMBOLS[@]}
    RANDOM_NUMBER="$(command shuf -i 1-$MAX -n 1)"

    KEY=${LIST_OF_KEYS[$RANDOM_NUMBER]}
    echo ${LIST_OF_SYMBOLS[$KEY]}
}

# ------------------------------------
# Git branch name presented in promt
# ------------------------------------
function getGitBranchName() {
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

# setting up colors
autoload -U colors && colors
for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
    eval $COLOR='%{$fg_no_bold[${(L)COLOR}]%}'  #wrap colours between %{ %} to avoid weird gaps in autocomplete
    eval BOLD_$COLOR='%{$fg_bold[${(L)COLOR}]%}'
done
eval GREY='%F{238}'
eval RESET='%f'

# Allow functions in (R)PROMPT
setopt PROMPT_SUBST
