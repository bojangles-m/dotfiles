alias gch='git checkout'
alias gc='git clone'
alias gs='git status'
alias gss='git status -s'
alias gadd='git add .'
alias gcm='git commit -m'
alias gcam='git commit -am'
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

# git reset
function grs() {
    local re='^[0-9]+$'

    [[ $1 =~ $re ]] && git reset || git reset -i HEAD~$1
}

# git squash
function gsq() {
    local re='^[0-9]+$'

    if [[ $1 =~ $re ]]; then
        git rebase -i HEAD~$1
    fi
}

# git stash helper function
function gst() {
    case "$1" in
        a)
            git stash apply stash@{"$2"}
            ;;
        l)
            git stash list
            ;;
        d)
            [[ -z "$2" ]] && git stash drop || git stash drop stash@{"$2"}
            ;;
        p)
            [[ -z "$2" ]] && git stash pop || git stash pop stash@{"$2"}
            ;;
        msg)
            git stash push -m $2
            ;;
        *) 
            git stash
            ;;
    esac
}
