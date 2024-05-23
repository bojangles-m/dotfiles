alias gch='git checkout'
alias gc='git clone'
alias gs='git status'
alias gss='git status -s'
alias gadd='git add .'
alias gcm='git commit -m'
alias gcam='git commit -am'
alias grs='git reset'
alias gl='git log'

# git worktree
alias gwa='git worktree add'
alias gwl='git worktree list'
alias gwr='git worktree remove'
alias gwp='git worktree prune'

# git diff
alias gd='git diff | mate'
# perform eslint only on changed files
alias gdfix='git diff --name-only | xargs pnpm exec eslint --fix --quiet'

# git push
alias gpu='git push'
alias gpuup='git push --set-upstream origin'

# git fetch
alias gf='git fetch'
alias gfo='git fetch origin'
alias gfp='git fetch origin preview:preview'
alias gfd='git fetch origin develop:develop'

# git branch
alias gb='git branch'
alias gbdchk="git branch -vv | awk '/: gone]/ {print \$1}'"
alias gbdall="git branch -vv | awk '/: gone]/ {print \$1}' | xargs git branch -D"

# git merge
alias gm='git merge'
alias gmm='git merge main'
alias gmom='git merge origin main'

# git pull
alias gpl='git pull'
alias gpm='git pull origin'
alias gpd='git pull origin develop'

# git remote
alias gr='git remote'
alias gru='git remote update'
alias grp='git remote prune origin'

# To rebase master into gfeature branch
# git rebase master
# git rebase and squash helpers
alias grb='git rebase'

re='^[0-9]+$'
function gsq() {
    if [[ $1 =~ $re ]] ; then
        echo "Is number: $1"
        git rebase -i HEAD~$1
    fi
}

# git stash helper function
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
    elif [ "$1" = "msg" ]; then
        git stash push -m $2
    fi
}
