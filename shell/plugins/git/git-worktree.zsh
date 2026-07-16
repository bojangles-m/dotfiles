# All worktrees live under $WORKTREE_DIR/<repo-name>/<branch>.
# Override the base folder by exporting WORKTREE_DIR before the shell loads.
: ${WORKTREE_DIR:="$HOME/dev/workspace"}

alias gwl='git worktree list'
alias gwp='git worktree prune'

# Sets the global REPO_DIR to $WORKTREE_DIR/<repo-name> for the current repo.
function _gw_repo_dir() {
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || {
        echo "gw: not inside a git repository" >&2
        return 1
    }
    common="${common:A}"                     # -> /abs/path/repo/.git
    REPO_DIR="$WORKTREE_DIR/${common:h:t}"    # -> $WORKTREE_DIR/repo
}

# Copy a ready-to-run "open in VS Code" command to the clipboard.
function _gw_copy_vscode() {
    command -v pbcopy >/dev/null || return 0
    printf 'vscode -n && vscode -a %s' "$1" | pbcopy
}

# Open the path in a new VS Code window with folder added to the workspace.
function _gw_open() {
    command -v code >/dev/null || { echo "gw: 'code' not found on PATH" >&2; return 1; }
    code -n && code -a "$1"
}

# gwa [-c | -o] <branch> [<start-point>]  -> worktree at $WORKTREE_DIR/<repo>/<branch>
# Existing branch -> checked out; new branch -> created from <start-point> (default HEAD).
# After creating, prints the worktree path, then:
#   -c : copy a "vscode -n && vscode -a <path>" command to the clipboard (default)
#   -o : open the new worktree in a new VS Code window
function gwa() {
    # Post-create action; defaults to copying the open-command. Add more flags below.
    local action="copy"
    local -a pos
    local arg
    for arg in "$@"; do
        case "$arg" in
            -c) action="copy" ;;
            -o) action="open" ;;
            *)  pos+=("$arg") ;;
        esac
    done

    local branch="${pos[1]}"
    if [[ -z "$branch" ]]; then
        echo "usage: gwa [-c|-o] <branch> [<start-point>]" >&2
        return 1
    fi
    _gw_repo_dir || return 1

    local src wt
    src="$(git rev-parse --show-toplevel)"   # current checkout, source of .env
    wt="$REPO_DIR/${branch//\//-}"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$wt" "$branch" || return 1
    else
        git worktree add -b "$branch" "$wt" "${pos[2]:-HEAD}" || return 1
    fi

    # Worktrees omit gitignored files; copy the root .env into the new worktree.
    if [[ -f "$src/.env" ]]; then
        cp "$src/.env" "$wt/.env"
    fi

    # Remember the most recent worktree so a bare `gwo` can reopen it.
    GW_LAST="$wt"

    echo "worktree: $wt"
    case "$action" in
        copy) _gw_copy_vscode "$wt" ;;
        open) _gw_open "$wt" ;;
    esac
}

# Open a worktree in a new VS Code window.
# With no <branch>, opens the worktree gwa created most recently (this shell).
# gwo [<branch>]
function gwo() {
    local wt
    if [[ -n "$1" ]]; then
        _gw_repo_dir || return 1
        wt="$REPO_DIR/${1//\//-}"
    else
        wt="$GW_LAST"
    fi
    if [[ -z "$wt" ]]; then
        echo "usage: gwo <branch>   (or run gwa first, then bare gwo)" >&2
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        echo "gwo: no worktree at $wt" >&2
        return 1
    fi
    _gw_open "$wt"
}

# Removes the worktree gwa created for <branch>
# gwr <branch> [extra flags]
function gwr() {
    local branch="$1"
    if [[ -z "$branch" ]]; then
        echo "usage: gwr <branch> [--force]" >&2
        return 1
    fi
    _gw_repo_dir || return 1
    local wt="$REPO_DIR/${branch//\//-}"
    shift

    # Explicit flags (e.g. --force) pass straight through.
    if (( $# )); then
        git worktree remove "$wt" "$@"
        return
    fi

    # If the only change is the .env gwa copied in, the worktree is effectively clean -> remove it silently.
    # Any real uncommitted work makes git refuse and warn instead.
    if [[ -z "$(git -C "$wt" status --porcelain 2>/dev/null | awk '$2 != ".env"')" ]]; then
        git worktree remove --force "$wt"
    else
        git worktree remove "$wt"
    fi
}
