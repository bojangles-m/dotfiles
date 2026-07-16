GWT_VERSION="1.0.0"

# All worktrees live under $WORKTREE_DIR/<repo-name>/<branch>.
# Override the base folder by exporting WORKTREE_DIR before the shell loads.
: ${WORKTREE_DIR:="$HOME/dev/workspace"}

# Command run inside each new worktree after creation, e.g. 'pnpm install'.
# Default Empty = do nothing.
# Control it from your shell: export GWT_POST_CREATE='pnpm install'
: ${GWT_POST_CREATE:=""}

# Gitignored files copied into each new worktree (only the ones that exist).
# Override files by exporting GWT_COPY_FILES before the shell loads.
(( ${+GWT_COPY_FILES} )) || GWT_COPY_FILES=(
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
    for f in $GWT_COPY_FILES; do
        [[ -f "$src/$f" ]] || continue
        mkdir -p "$wt/${f:h}"
        cp "$src/$f" "$wt/$f"
    done

    # Remember the most recent worktree so a bare `gwo` can reopen it.
    GW_LAST="$wt"

    echo "worktree: $wt"

    # Optional shell-controlled bootstrap (e.g. GWT_POST_CREATE='pnpm install').
    if [[ -n "$GWT_POST_CREATE" ]]; then
        ( cd "$wt" && eval "$GWT_POST_CREATE" ) \
            || echo "gwa: post-create command failed — worktree kept at $wt" >&2
    fi

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

    # Ignore the files gwa seeded (GWT_COPY_FILES): if the worktree is otherwise clean,
    # remove it silently; any real uncommitted work makes git refuse and warn instead.
    local -a dirty
    local line p
    for line in "${(@f)$(git -C "$wt" status --porcelain -uall 2>/dev/null)}"; do
        [[ -z "$line" ]] && continue
        p="${line[4,-1]}"                            # strip the "XY " status prefix
        (( ${GWT_COPY_FILES[(Ie)$p]} )) && continue   # skip files gwa seeded
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
git worktree helpers
Worktrees are created under: $WORKTREE_DIR/<repo>/<branch>

Usage:
  gwa [-c | -o] <branch> [<start-point>]
      Create a new worktree.
        -c    Copy an "Open in VS Code" command to the clipboard (default)
        -o    Open the worktree in a new VS Code window

  gwo [<branch>]                    Open a worktree in VS Code. Opens the most recently if <branch> is omitted.
  gwcd [<branch>]                   Change into a worktree. Uses the most recently if <branch> is omitted.
  gwr <branch> [--force]            Remove a worktree.
  gwl                               List all worktrees.
  gwp                               Prune stale worktree entries.
  gwt [-v | -h]                     Show this help or version.

Configuration:
  Set these in your shell (or ~/.zshrc). They affect the next \`gwa\` command.
        WORKTREE_DIR        base folder that holds all worktrees
                            e.g.  export WORKTREE_DIR=~/dev/wt
        GWT_COPY_FILES      gitignored files copied into each new worktree (if present)
                            e.g.  GWT_COPY_FILES=(.env .npmrc)   # in this file
        GWT_POST_CREATE     command run inside the new worktree after it is created
                            e.g.  GWT_POST_CREATE='pnpm install' gwa my-branch
EOF
}

# Help for the gw worktree commands.
# gwt [-v | -h] (no args: help + version)
#   -v : version    
#   -h : help
function gwt() {
    case "$1" in
        -v) echo "gwt $GWT_VERSION" ;;
        -h) _gw_help ;;
        *)  _gw_help; echo; echo "version: $GWT_VERSION" ;;
    esac
}

# ---------------------------------------------------------------------------
# Tab completion
# ---------------------------------------------------------------------------

# complete short branch names — local + remote (origin/ stripped), deduped.
# Short names are what gwa expects; 'origin/x' would make a bogus local branch.
function _gw_complete_branches() {
    local -aU names   # -U dedupes local vs remote of the same name
    names=(
        ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
        ${(f)"$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes 2>/dev/null)"}
    )
    compadd -- ${names:#HEAD}
}

# gwo / gwcd / gwr: complete names of existing worktrees under $REPO_DIR.
function _gw_complete_worktrees() {
    _gw_repo_dir 2>/dev/null || return
    local -a wts
    wts=(${REPO_DIR}/*(/N))   # (/) dirs only, N nullglob
    compadd -- ${wts:t}       # :t -> basenames
}

(( $+functions[compdef] )) && {
    compdef _gw_complete_branches gwa
    compdef _gw_complete_worktrees gwo gwcd gwr
}
