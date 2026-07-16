# All worktrees live under $WORKTREE_DIR/<repo-name>/<branch>.
# Override the base folder by exporting WORKTREE_DIR before the shell loads.
: ${WORKTREE_DIR:="$HOME/dev/workspace"}
GW_VERSION="1.0.0"

# Copy ignored files only if it exists in the source checkout
GW_COPY_FILES=(
    .env                                    # FE
    application/config/config-private.php   # BE
    .vscode/launch.json                     # optional
    .vscode/settings.json                   # optional
)

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
    REPO_DIR="$WORKTREE_DIR/${common:h:t}"   # -> $WORKTREE_DIR/repo
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

# Worktree at $WORKTREE_DIR/<repo>/<branch>
# gwa [-c | -o] <branch> [<start-point>]
#   -c : copy a "vscode -n && vscode -a <path>" command to the clipboard (default)
#   -o : open the new worktree in a new VS Code window, folder added to the workspace
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
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        print -r -- $'\e[38;5;208m'"gwa: The '$branch' already exists on origin — creating from origin/$branch, not HEAD"$'\e[0m'
        git worktree add --track -b "$branch" "$wt" "origin/$branch" || return 1
    else
        git worktree add -b "$branch" "$wt" "${pos[2]:-HEAD}" || return 1
    fi

    # Worktrees omit gitignored files; seed the ones this repo needs
    local f
    for f in $GW_COPY_FILES; do
        [[ -f "$src/$f" ]] || continue
        mkdir -p "$wt/${f:h}"
        cp "$src/$f" "$wt/$f"
    done

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

# cd into a worktree. Without <branch>, cd into recently created worktree.
# gwcd [<branch>]
function gwcd() {
    local wt
    if [[ -n "$1" ]]; then
        _gw_repo_dir || return 1
        wt="$REPO_DIR/${1//\//-}"
    else
        wt="$GW_LAST"
    fi
    if [[ -z "$wt" ]]; then
        echo "usage: gwcd <branch>   (or run gwa first, then bare gwcd)" >&2
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        echo "gwcd: no worktree at $wt" >&2
        return 1
    fi
    cd "$wt"
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

    # Ignore the files gwa seeded (GW_COPY_FILES): if the worktree is otherwise clean,
    # remove it silently; any real uncommitted work makes git refuse and warn instead.
    local -a dirty
    local line p
    for line in "${(@f)$(git -C "$wt" status --porcelain -uall 2>/dev/null)}"; do
        [[ -z "$line" ]] && continue
        p="${line[4,-1]}"                            # strip the "XY " status prefix
        (( ${GW_COPY_FILES[(Ie)$p]} )) && continue   # skip files gwa seeded
        dirty+=("$p")
    done
    if (( ${#dirty} == 0 )); then
        git worktree remove --force "$wt"
    else
        git worktree remove "$wt"
    fi
}

function _gw_help() {
    cat <<EOF
git worktree helpers — worktrees live under: $WORKTREE_DIR/<repo>/<branch>

  gwa [-c | -o] <branch> [<start-point>]   create a worktree (seeds GW_COPY_FILES)
                                           -c  copy an "open in VS Code" command (default)
                                           -o  open it in a new VS Code window
  gwo [<branch>]                         open a worktree in VS Code (most recent if omitted)
  gwcd [<branch>]                        cd into a worktree (most recent if omitted)
  gwr <branch> [--force]                 remove a worktree
  gwl                                    list worktrees
  gwp                                    prune stale worktree entries
  gwt [-v | -h]                            show this help / version
EOF
}

# Help for the gw worktree commands.
# gwt [-v | -h] (no args: help + version)
#   -v : version    
#   -h : help
function gwt() {
    case "$1" in
        -v) echo "gwt $GW_VERSION" ;;
        -h) _gw_help ;;
        *)  _gw_help; echo; echo "version: $GW_VERSION" ;;
    esac
}
