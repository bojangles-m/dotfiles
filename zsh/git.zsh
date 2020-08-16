# git aliases
alias gch='git checkout'
alias gc='git clone'
alias gb='git branch'
alias gm='git merge'
alias gd='git diff | mate'
alias gf='git fetch'
alias gpl='git pull'
alias gpu='git push'
alias gs='git status'
alias gss='git status -s'
alias gadd='git add .'
alias gcm='git commit -am'
alias gpd='git pull origin develop'
alias gpm='git pull origin master'
alias gfd='git fetch origin develop:develop'
alias gfm='git fetch origin master:master'
alias gfp='git fetch origin preview:preview'
alias grb='git rebase'
alias grs='git reset'
alias gl='git log'

# making git stash faster to use
function gst() {
    if [ -z "$1" ]; then        
        git stash
    elif [ "$1" = "a" ]; then
        git stash apply stash@{"$2"}
    elif [ "$1" = "l"  ]; then
        git stash list
    elif [ "$1" = "d" ]; then
        if [ -z "$2" ]; then        
            git stash drop
        else 
            git stash drop stash@{"$2"}
        fi
    elif [ "$1" = "p" ]; then
        if [ -z "$2" ]; then        
            git stash pop
        else 
            git stash pop stash@{"$2"}
        fi
    fi
}