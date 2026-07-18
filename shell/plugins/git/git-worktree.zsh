GWT_VERSION="1.0.3"

# ---------------------------------------------------------------------------
# All worktrees live under $GWT_WORKTREE_DIR/<repo-name>/<branch>.
# Shell control: export GWT_WORKTREE_DIR='$HOM/<repo-name>/<branch>'
# ---------------------------------------------------------------------------
: ${GWT_WORKTREE_DIR:="$HOME/dev/workspace"}

# ---------------------------------------------------------------------------
# Command run inside each new worktree after creation, e.g. 'pnpm install'.
# Default Empty = do nothing.
# Shell control: export GWT_POST_INIT_CMD='pnpm install'
# ---------------------------------------------------------------------------
: ${GWT_POST_INIT_CMD:=""}

# ---------------------------------------------------------------------------
# Command used to open a worktree ({} = its path; if absent, the path is appended)
# Default is VS Code.
# Shell control: export GWT_OPEN_CMD='cursor {}'
# ---------------------------------------------------------------------------
: ${GWT_OPEN_CMD:='code -n && code -a {}'}

# ---------------------------------------------------------------------------
# Gitignored files copied into each new worktree (only the ones that exist).
# Shell control: export GWT_COPY_FILES=(<files>)
# ---------------------------------------------------------------------------
(( ${+GWT_COPY_FILES} )) || GWT_COPY_FILES=(
    .env                                    # FE
    application/config/config-private.php   # BE
    .vscode/launch.json                     # optional
    .vscode/settings.json                   # optional
)

# ---------------------------------------------------------------------------
# Interactive picker by fzf (used only if installed).
# Shell control: export GWT_PICKER_OPTIONS='--height=60% --preview-window=down'
# ---------------------------------------------------------------------------
: ${GWT_PICKER_OPTIONS:=""}

alias gwl='git worktree list'
alias gwp='git worktree prune'

# Help for the gw worktree commands.
function gwt() {
    case "$1" in
        -v) _gwt_info "gwt $GWT_VERSION" ;;
        -h) _gwt_help ;;
        *)  _gwt_help; echo;;
    esac
}

function _gwt_help() {
    cat <<EOF
gwt: v$GWT_VERSION
Worktrees are created under: $GWT_WORKTREE_DIR/<repo>/<branch>

Usage:
  gwa [-c | -o] [<branch>] [<start-point>]
      Create a new worktree. No <branch>: fzf picker of branches without a worktree.
          -c    Copy the "open" command to the clipboard (default)
          -o    Open the worktree in your editor
                (both use \$GWT_OPEN_CMD — VS Code by default)

  gwo [<branch>]                    Open a worktree in your editor. No <branch>: fzf picker (else the most recent).
  gwcd [<branch>]                   Change into a worktree. No <branch>: fzf picker (else the most recent).

  gwr [-d | -D] [<branch>] [--force]
      Remove a worktree. The branch is KEPT unless you pass -d/-D.
      No <branch>: fzf multi-picker (mark several with Tab, remove all).
          -d    Also delete the branch — safe: git refuses if it has unmerged commits.
                (A branch with no commits of its own is deleted; nothing is lost.)
          -D    Also delete the branch — force: deletes even with unmerged commits.

  gwclean [-n | --dry-run]
      Remove "stale" worktrees: branch has no commits of its own beyond the default
      branch (merged or never diverged), or its remote branch is gone.
      Branches with unpushed/unmerged commits are KEPT — use gwr for those.
          -n    Dry run: preview what would be removed; removes nothing.

  gws [-a | --all]                  Worktree status dashboard: branch, dirty, ahead/behind, last commit.
                                    ⚑ stale = a gwclean candidate. -a shows every repo under GWT_WORKTREE_DIR.
  gwl                               List all worktrees.
  gwp                               Prune stale worktree entries.
  gwt [-v | -h]                     Show this help or version.

Configuration:
  Set these in your shell (or ~/.zshrc). They affect the next \`gwa\` command.
        GWT_WORKTREE_DIR            base folder that holds all worktrees
                                    e.g.  export GWT_WORKTREE_DIR=~/dev/wt
        GWT_COPY_FILES              gitignored files copied into each new worktree (if present)
                                    e.g.  GWT_COPY_FILES=(.env .npmrc)   # in this file
        GWT_POST_INIT_CMD           command run inside the new worktree after it is created
                                    e.g.  GWT_POST_INIT_CMD='pnpm install' gwa my-branch
        GWT_OPEN_CMD                command used to open a worktree ({} = its path)
                                    default: code -n && code -a {}
                                    e.g.  export GWT_OPEN_CMD='cursor {}'
EOF
}

# Worktree at $GWT_WORKTREE_DIR/<repo>/<branch>
# gwa [-c | -o] [<branch>] [<start-point>]
#   -c : copy the open-command ($GWT_OPEN_CMD) to the clipboard (default)
#   -o : open the new worktree via $GWT_OPEN_CMD
# With no <branch>: fzf picker of branches that don't have a worktree yet.
function gwa() {
    local -a flags pos
    local action="copy"                      # default; add more flags below
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -c) action="copy" ;;
            -o) action="open" ;;
            *)  _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    local branch="${pos[1]}" startpoint="${pos[2]}"
    if [[ -z "$branch" ]]; then
        # No branch given: pick an existing branch that has no worktree yet.
        if _gwt_is_picker_available; then
            branch="$(_gwt_pick_branch)" || { [[ $? == 130 ]] && print -z -- "${0}${flags:+ $flags} "; return 0; }   # ESC -> reinject cmd
            [[ -z "$branch" ]] && return 0
        else
            _gwt_error "usage: [-c|-o] <branch> [<start-point>]"
            return 1
        fi
    fi

    local src wt REPLY
    _gwt_wt_path "$branch" || return 1
    wt="$REPLY"
    src="$(git rev-parse --show-toplevel)"   # current checkout, source of .env

    # If this branch already has a worktree, reuse it instead of failing.
    local existing
    existing="$(_gwt_worktree_for_branch "$branch")"
    if [[ -n "$existing" ]]; then
        GWT_LAST="$existing"
        case "$action" in
            open) _gwt_info "'$branch' already has a worktree at $existing — opening it"
                  _gwt_open "$existing" ;;
            copy) _gwt_info "'$branch' already has a worktree at $existing"
                  _gwt_copy "$existing" ;;
        esac
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$wt" "$branch" >/dev/null || return 1
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        _gwt_note "'$branch' already exists on origin — creating from origin/$branch, not HEAD"
        git worktree add --track -b "$branch" "$wt" "origin/$branch" >/dev/null || return 1
    else
        git worktree add -b "$branch" "$wt" "${startpoint:-HEAD}" >/dev/null || return 1
    fi

    # Worktrees omit gitignored files; seed the ones this repo needs
    for f in $GWT_COPY_FILES; do
        [[ -f "$src/$f" ]] || continue
        mkdir -p "$wt/${f:h}"
        cp "$src/$f" "$wt/$f"
    done

    # Remember the most recent worktree so a bare `gwo` can reopen it.
    GWT_LAST="$wt"

    _gwt_info "worktree: $wt"

    # Optional shell-controlled bootstrap (e.g. GWT_POST_INIT_CMD='pnpm install').
    if [[ -n "$GWT_POST_INIT_CMD" ]]; then
        ( cd "$wt" && eval "$GWT_POST_INIT_CMD" ) \
            || _gwt_error "post-create command failed — worktree kept at $wt"
    fi

    case "$action" in
        copy) _gwt_copy "$wt" ;;
        open) _gwt_open "$wt" ;;
    esac
}


# Open a worktree via $GWT_OPEN_CMD (VS Code by default).
# With no <branch>: fzf picker if available, else the worktree gwa created most
# recently in this shell ($GWT_LAST).
# gwo [<branch>]
function gwo() {
    local wt REPLY
    if [[ -n "$1" ]]; then
        _gwt_wt_path "$1" || return 1
        wt="$REPLY"
    elif _gwt_is_picker_available; then
        wt="$(_gwt_pick -p 'open')" || { [[ $? == 130 ]] && print -z -- "$0 "; return 0; }   # ESC -> reinject cmd
    else
        wt="$GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gwt_error "usage: <branch>   (or run gwa first, then bare gwo)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gwt_error "no worktree at $wt"
        return 1
    fi
    _gwt_open "$wt"
}

# cd into a worktree. Without <branch>: fzf picker if available, else the most
# recently created worktree ($GWT_LAST).
# gwcd [<branch>]
function gwcd() {
    local wt REPLY
    if [[ -n "$1" ]]; then
        _gwt_wt_path "$1" || return 1
        wt="$REPLY"
    elif _gwt_is_picker_available; then
        wt="$(_gwt_pick -p 'cd')" || { [[ $? == 130 ]] && print -z -- "$0 "; return 0; }   # ESC -> reinject cmd
    else
        wt="$GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gwt_error "usage: <branch>   (or run gwa first, then bare gwcd)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gwt_error "no worktree at $wt"
        return 1
    fi
    cd "$wt"
}

# Remove the worktree gwa created for <branch>.
# With no <branch>: fzf multi-picker if available (mark several, remove all).
# gwr [-d | -D] [<branch>] [git-worktree-remove flags, e.g. --force]
#   -d : also delete the branch (safe: refuses if it has unmerged commits)
#   -D : also delete the branch (force: even if unmerged)
function gwr() {
    local -a flags pos passthru
    local delete_flag=""             # "" | -d (safe) | -D (force), mirrors git branch
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -d|-D) delete_flag="$f" ;;
            *)     passthru+=("$f") ;;   # e.g. --force -> git worktree remove
        esac
    done

    # Target worktree path(s): an explicit <branch>, else the interactive picker.
    local -a targets
    local wt wt_branch unique rc=0 REPLY
    if [[ -n "${pos[1]}" ]]; then
        _gwt_wt_path "${pos[1]}" || return 1
        wt="$REPLY"; targets=("$wt")
    elif _gwt_is_picker_available; then
        targets=("${(@f)$(_gwt_pick -m --skip-current -p 'remove')}") || { [[ $? == 130 ]] && print -z -- "${0}${flags:+ $flags} "; return 0; }   # ESC -> reinject cmd
        (( ${#targets} )) || return 0            # nothing selected -> no-op
    else
        _gwt_error "usage: [-d|-D] <branch> [--force]"
        return 1
    fi

    for wt in $targets; do
        # Capture the branch checked out before removing it, so a -d/-D delete
        # targets the right ref even when <branch> was given in flattened form.
        wt_branch=""
        [[ -n "$delete_flag" ]] && wt_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"

        # Explicit flags -> pass straight through. Otherwise: clean (bar seeded files)
        # removes silently with --force; real uncommitted work makes git refuse & warn.
        if (( ${#passthru} )); then
            git worktree remove "$wt" "${passthru[@]}" || { rc=1; continue; }
        elif _gwt_worktree_is_clean "$wt"; then
            git worktree remove --force "$wt" || { rc=1; continue; }
        else
            git worktree remove "$wt" || { rc=1; continue; }
        fi

        if [[ -n "$delete_flag" && -n "$wt_branch" && "$wt_branch" != HEAD ]]; then
            # Count commits unique to the branch before deleting (ref still exists).
            unique="$(git rev-list --count "HEAD..$wt_branch" 2>/dev/null)"
            if git branch "$delete_flag" "$wt_branch"; then
                # Make the "why did it delete?" self-evident: an empty branch is safe.
                [[ "$unique" == 0 ]] && \
                    _gwt_info "branch '$wt_branch' had no unique commits — nothing was lost"
            fi
        fi
    done
    return $rc
}

# Remove "stale" worktrees: branch has no commits of its own beyond the default
# branch (merged or never diverged), or its remote branch is gone — then delete those
# branches. Dirty and default-branch worktrees are kept.
# gwclean [-n]
#   -n | --dry-run: preview what would be removed, without removing anything
function gwclean() {
    local -a flags pos
    local dry=""
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -n|--dry-run) dry=1 ;;
            *) _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    local repo_dir REPLY
    _gwt_repo_dir || return 1
    repo_dir="$REPLY"
    git fetch --prune --quiet origin 2>/dev/null

    local -a wts=(${repo_dir}/*(/N))
    (( ${#wts} )) || { _gwt_info "gwclean: no worktrees under $repo_dir"; return 0; }

    local default_branch
    default_branch="${$(_gwt_default_branch)#origin/}"

    local wt_dir branch item
    local -a removed skipped
    for wt_dir in $wts; do
        branch="$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        [[ -z "$branch" || "$branch" == HEAD || "$branch" == (main|master) || "$branch" == "$default_branch" ]] && continue
        _gwt_branch_stale "$branch" || continue
        if ! _gwt_worktree_is_clean "$wt_dir"; then
            skipped+=("${wt_dir:t} ($branch) — uncommitted changes")
            continue
        fi
        if [[ -n "$dry" ]]; then
            removed+=("${wt_dir:t} ($branch)")                       # would remove; don't touch anything
        elif git worktree remove --force "$wt_dir" 2>/dev/null; then
            git branch -D "$branch" >/dev/null 2>&1
            removed+=("${wt_dir:t} ($branch)")
        else
            skipped+=("${wt_dir:t} ($branch) — remove failed")
        fi
    done

    local verb="removed"; [[ -n "$dry" ]] && verb="would remove"
    if (( ${#removed} )); then
        _gwt_info "gwclean: $verb ${#removed} worktree(s):"
        for item in $removed; do _gwt_info "  $item"; done
    else
        _gwt_info "gwclean: nothing to clean"
    fi
    if (( ${#skipped} )); then
        _gwt_info "gwclean: skipped ${#skipped}:"
        for item in $skipped; do _gwt_info "  $item"; done
    fi
    [[ -n "$dry" ]] && (( ${#removed} )) && _gwt_info "gwclean: dry run — nothing removed; run 'gwclean' to apply"
}

# Sets REPLY to $GWT_WORKTREE_DIR/<repo-name> for the current repo.
function _gwt_repo_dir() {
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || {
        _gwt_error "current directory is not inside a git repository"
        return 1
    }
    common="${common:A}"                     # -> /abs/path/repo/.git
    REPLY="$GWT_WORKTREE_DIR/${common:h:t}"   # -> $GWT_WORKTREE_DIR/repo
}

# Split argv into caller-local arrays `flags` (tokens starting with -) and
# `pos` (the rest). Caller must declare: local -a flags pos
function _gwt_split_args() {
    flags=(); pos=()
    local a
    for a in "$@"; do
        case "$a" in
            -*) flags+=("$a") ;;
            *)  pos+=("$a") ;;
        esac
    done
}

# Sets REPLY to the worktree path for <branch>: $GWT_WORKTREE_DIR/<repo>/<branch>.
function _gwt_wt_path() {
    _gwt_repo_dir || return 1                # REPLY = repo dir
    REPLY="$REPLY/${1//\//-}"
}

# Print the path of the worktree that has <branch> checked out, if any.
function _gwt_worktree_for_branch() {
    local target="refs/heads/$1" wtpath="" line
    for line in "${(@f)$(git worktree list --porcelain 2>/dev/null)}"; do
        case "$line" in
            "worktree "*)      wtpath="${line#worktree }" ;;
            "branch $target")  print -r -- "$wtpath"; return 0 ;;
        esac
    done
    return 1
}

# Expand $GWT_OPEN_CMD for path <$1>: substitute {} (or append if absent).
# <$2> = quoting style for the path: 'q' shell-quotes it (safe for eval),
# anything else wraps it in plain double quotes (readable, for clipboard).
function _gwt_open_cmd() {
    local ph='{}' p
    [[ "$2" == q ]] && p="${(q)1}" || p="\"$1\""
    if [[ "$GWT_OPEN_CMD" == *"$ph"* ]]; then
        print -r -- "${GWT_OPEN_CMD//$ph/$p}"
    else
        print -r -- "$GWT_OPEN_CMD $p"
    fi
}

# Copy a ready-to-run "open" command (per $GWT_OPEN_CMD) to the clipboard.
function _gwt_copy() {
    command -v pbcopy >/dev/null || return 0
    _gwt_open_cmd "$1" | pbcopy
}

# Open the worktree at <path> using $GWT_OPEN_CMD.
function _gwt_open() {
    eval "$(_gwt_open_cmd "$1" q)"
}

# True if the worktree at <path> has no real changes.
function _gwt_worktree_is_clean() {
    local line p
    for line in "${(@f)$(git -C "$1" status --porcelain -uall 2>/dev/null)}"; do
        [[ -z "$line" ]] && continue
        p="${line[4,-1]}"                          # strip the "XY " status prefix
        (( ${GWT_COPY_FILES[(Ie)$p]} )) && continue
        return 1                                   # a real change -> not clean
    done
    return 0
}

# Print the repo's default branch as a remote ref, e.g. "origin/main".
# Prefers the remote's advertised HEAD (set at clone time); else guesses.
# $1 = optional repo dir to run against (default: cwd).
function _gwt_default_branch() {
    local -a C; [[ -n "$1" ]] && C=(-C "$1")
    local ref b
    ref="$(git $C symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" \
        && { print -r -- "$ref"; return 0; }
    for b in main master trunk develop; do
        if git $C show-ref --verify --quiet "refs/remotes/origin/$b"; then
            print -r -- "origin/$b"; return 0
        fi
    done
    return 1
}

# "Stale" = branch has no commits of its own beyond the default branch (merged or
# never diverged), or its upstream is gone. True for such branches — safe to remove.
# $1 = branch, $2 = optional repo dir to run against (default: cwd).
function _gwt_branch_stale() {
    local -a C; [[ -n "$2" ]] && C=(-C "$2")
    local base; base="$(_gwt_default_branch "$2")"
    [[ -n "$base" ]] && git $C merge-base --is-ancestor "refs/heads/$1" "$base" 2>/dev/null && return 0
    [[ "$(git $C for-each-ref --format='%(upstream:track)' "refs/heads/$1" 2>/dev/null)" == *gone* ]]
}

# ---------------------------------------------------------------------------
# Tab completion
# ---------------------------------------------------------------------------

# complete short branch names — local + remote (origin/ stripped), deduped.
# Short names are what gwa expects; 'origin/x' would make a bogus local branch.
function _gwt_complete_branches() {
    local -aU names   # -U dedupes local vs remote of the same name
    names=(
        ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
        ${(f)"$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes 2>/dev/null)"}
    )
    compadd -- ${names:#HEAD}
}

# gwo / gwcd / gwr: complete names of existing worktrees for the current repo.
function _gwt_complete_worktrees() {
    local REPLY
    _gwt_repo_dir 2>/dev/null || return
    local -a wts
    wts=(${REPLY}/*(/N))   # (/) dirs only, N nullglob
    compadd -- ${wts:t}       # :t -> basenames
}

(( $+functions[compdef] )) && {
    compdef _gwt_complete_branches gwa
    compdef _gwt_complete_worktrees gwo gwcd gwr
}

# ---------------------------------------------------------------------------
# Worktree status dashboard.
#
# Columns:
#   marker       ▶ current worktree · ⌂ main worktree
#   branch       branch checked out in the worktree
#   state        dirty / clean  (any uncommitted changes?)
#   sync         vs upstream: ↑ahead ↓behind · synced · gone · local
#   last commit  subject + how long ago
#
# Rows are sorted newest-commit-first.
# ⚑ stale marks branches gwclean would remove (merged, never diverged, or gone).
#
# Usage: gws [-a | --all]
#   -a   show every repo under $GWT_WORKTREE_DIR (works from any directory)
# ---------------------------------------------------------------------------

# Print one repository's worktrees as dashboard rows (helper for gws).
function _gwt_gather_repo() {
    local label="$1" repo_dir="$2"
    local base default_branch
    base="$(_gwt_default_branch "$repo_dir")"        # computed ONCE per repo (not per worktree)
    default_branch="${base#origin/}"

    # Collect (path, branch) for every worktree of this repo; main is listed first.
    local -a wt_paths wt_branches
    local line cpath="" cbranch=""
    for line in "${(@f)$(git -C "$repo_dir" worktree list --porcelain 2>/dev/null)}"; do
        case "$line" in
            "worktree "*)
                [[ -n "$cpath" ]] && { wt_paths+=("$cpath"); wt_branches+=("$cbranch"); }
                cpath="${line#worktree }"; cbranch="(detached)" ;;
            "branch refs/heads/"*) cbranch="${line#branch refs/heads/}" ;;
        esac
    done
    [[ -n "$cpath" ]] && { wt_paths+=("$cpath"); wt_branches+=("$cbranch"); }
    (( ${#wt_paths} )) || return 0

    # ONE bulk query for per-branch metadata: date, "when", upstream, track, subject
    # (\x1f field separator; parsed with %%/# to preserve empty fields).
    local SEP=$'\x1f'
    local -A m_ts m_when m_up m_track m_subj
    local rec b
    local fmt="%(refname:short)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)${SEP}%(upstream:short)${SEP}%(upstream:track)${SEP}%(contents:subject)"
    for rec in "${(@f)$(git -C "$repo_dir" for-each-ref --format=$fmt refs/heads 2>/dev/null)}"; do
        b="${rec%%${SEP}*}";       rec="${rec#*${SEP}}"
        m_ts[$b]="${rec%%${SEP}*}";   rec="${rec#*${SEP}}"
        m_when[$b]="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        m_up[$b]="${rec%%${SEP}*}";   rec="${rec#*${SEP}}"
        m_track[$b]="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        m_subj[$b]="$rec"
    done

    # ONE bulk query for the "merged into default" set (replaces per-branch merge-base).
    local -A merged
    if [[ -n "$base" ]]; then
        for b in "${(@f)$(git -C "$repo_dir" branch --merged "$base" --format='%(refname:short)' 2>/dev/null)}"; do
            [[ -n "$b" ]] && merged[$b]=1
        done
    fi

    local -a group dirty_flag pids
    local i d branch ts when subject up track ahead behind mark stale is_cur state sync sync_color
    local info restd branch_trunc subject_trunc branch_cell state_cell sync_cell subject_cell row tmpd

    # The dirty check is the one per-worktree working-tree scan. The scans are
    # independent, so run them in parallel and collect the results — wall-time is
    # ~the slowest single scan instead of the sum. (no_monitor: no job-control spam.)
    setopt local_options no_monitor
    tmpd="$(mktemp -d "${TMPDIR:-/tmp}/gws.XXXXXX")"
    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        d="${wt_paths[$i]}"
        { [[ -n "$(git -C "$d" --no-optional-locks status --porcelain 2>/dev/null)" ]] \
            && print dirty || print clean } > "$tmpd/$i" &
        pids+=($!)
    done
    wait $pids
    for (( i = 1; i <= ${#wt_paths}; i++ )); do dirty_flag[$i]="$(< $tmpd/$i)"; done
    rm -rf "$tmpd"

    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        d="${wt_paths[$i]}"; branch="${wt_branches[$i]}"
        (( n_total++ ))

        # metadata from the bulk query; detached HEADs aren't in refs/heads -> fall back
        if [[ "$branch" == "(detached)" ]]; then
            info="$(git -C "$d" log -1 --format='%ct%x1f%cr%x1f%s' 2>/dev/null)"
            ts="${info%%$'\x1f'*}"; restd="${info#*$'\x1f'}"
            when="${restd%%$'\x1f'*}"; subject="${restd#*$'\x1f'}"
            [[ -n "$ts" ]] || ts=0; [[ -n "$when" ]] || when="-"; [[ -n "$subject" ]] || subject="-"
            sync="-"; sync_color="$C_DIM"
        else
            ts="${m_ts[$branch]:-0}"; when="${m_when[$branch]:--}"; subject="${m_subj[$branch]:--}"
            up="${m_up[$branch]}"; track="${m_track[$branch]}"
            if   [[ "$track" == *gone* ]]; then sync="gone";   sync_color="$C_GONE"
            elif [[ -z "$up" ]];           then sync="local";  sync_color="$C_DIM"
            elif [[ -z "$track" ]];        then sync="synced"; sync_color="$C_OK"
            else
                ahead=0; behind=0
                [[ "$track" == *"ahead "* ]]  && { ahead="${track#*ahead }";   ahead="${ahead%%[^0-9]*}"; }
                [[ "$track" == *"behind "* ]] && { behind="${track#*behind }"; behind="${behind%%[^0-9]*}"; }
                sync="↑${ahead:-0} ↓${behind:-0}"
                if   (( ${ahead:-0} > 0 && ${behind:-0} > 0 )); then sync_color="$C_DIVERGE"
                elif (( ${ahead:-0} > 0 ));                      then sync_color="$C_OK"
                else                                                 sync_color="$C_WARN"; fi
            fi
        fi

        # dirty state was computed in parallel above
        if [[ "${dirty_flag[$i]}" == dirty ]]; then
            state="dirty"; (( n_dirty++ ))
        else
            state="clean"
        fi

        # stale = merged into default (bulk set) OR upstream gone; same guards as gwclean
        stale=""
        if [[ "$branch" != "(detached)" && "$branch" != "$default_branch" && "$branch" != (main|master) ]] \
           && { [[ -n "${merged[$branch]}" ]] || [[ "$sync" == gone ]]; }; then
            stale=1; (( n_stale++ ))
            [[ "$state" == clean ]] && (( n_removable++ ))
        fi

        # marker: current worktree > main worktree > none
        if [[ -n "$here" && "$d" == "$here" ]]; then mark="▶"
        elif (( i == 1 ));                        then mark="⌂"
        else                                           mark=" "; fi

        # pad on plain text, then wrap in color -> columns stay aligned
        branch_trunc="${branch[1,20]}";   branch_cell="${(r:20:)branch_trunc}"
        subject_trunc="${subject[1,30]}"; subject_cell="${(r:30:)subject_trunc}"
        state_cell="${(r:6:)state}";      sync_cell="${(r:11:)sync}"
        is_cur=""; [[ -n "$here" && "$d" == "$here" ]] && is_cur=1

        if [[ -n "$stale" ]]; then
            # stale rows recede: render plain, then dim the whole line
            row="${C_DIM}$mark ${branch_cell}   ${state_cell} ${sync_cell} ${subject_cell}    ${when}  ⚑ stale${C_RESET}"
        else
            [[ "$mark" == "▶" ]] && mark="${C_CUR}▶${C_RESET}"
            [[ "$mark" == "⌂" ]] && mark="${C_MAIN}⌂${C_RESET}"
            [[ -n "$is_cur" ]] && branch_cell="${C_CUR}${branch_cell}${C_RESET}"          # current branch pops
            if [[ "$state" == dirty ]]; then state_cell="${C_DIRTY}${state_cell}${C_RESET}"
            else                             state_cell="${C_DIM}${state_cell}${C_RESET}"; fi   # clean/unknown recedes
            sync_cell="${sync_color}${sync_cell}${C_RESET}"
            row="$mark ${branch_cell}   ${state_cell} ${sync_cell} ${subject_cell}    ${when}"
        fi
        group+=("${ts}"$'\t'"$row")
    done

    group=("${(@On)group}")                       # newest commit first
    (( n_shown++ ))
    (( n_shown > 1 )) && _gwt_info ""               # blank line between repo groups
    [[ -n "$label" ]] && _gwt_info "${C_BOLD}${label}${C_RESET}"
    local r
    for r in $group; do _gwt_info "${r#*$'\t'}"; done
}

function gws() {
    local -a flags pos
    local all="" REPLY
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -a|--all) all=1 ;;
            *) _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    # Color codes — only on a real terminal (this fd, not a subshell) & no NO_COLOR.
    local C_RESET="" C_DIM="" C_BOLD="" C_CUR="" C_MAIN="" C_DIRTY="" C_OK="" C_WARN="" C_DIVERGE="" C_GONE=""
    if [[ -t 1 && -z "$NO_COLOR" ]]; then
        C_RESET=$'\e[0m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'
        C_CUR=$'\e[1;36m'    # bold cyan — current worktree
        C_MAIN=$'\e[34m'     # blue      — main worktree
        C_DIRTY=$'\e[33m'    # yellow    — uncommitted changes
        C_OK=$'\e[32m'       # green     — synced / ahead
        C_WARN=$'\e[33m'     # yellow    — behind
        C_DIVERGE=$'\e[35m'  # magenta   — diverged (ahead & behind)
        C_GONE=$'\e[31m'     # red       — upstream gone
    fi

    local here; here="$(git rev-parse --show-toplevel 2>/dev/null)"
    local n_total=0 n_dirty=0 n_stale=0 n_removable=0 n_repos=0 n_shown=0

    local h1=BRANCH h2=STATE h3=SYNC h4="LAST COMMIT"
    local header="${C_BOLD}  ${(r:20:)h1}   ${(r:6:)h2} ${(r:11:)h3} ${(r:30:)h4}    WHEN${C_RESET}"

    if [[ -n "$all" ]]; then
        # every repo under $GWT_WORKTREE_DIR — works from anywhere, no repo needed
        local -a repodirs=(${GWT_WORKTREE_DIR}/*(/N))
        (( ${#repodirs} )) || { _gwt_info "gws: no worktrees under $GWT_WORKTREE_DIR"; return 0; }
        _gwt_info "$header"
        local repodir
        local -a wtsub
        for repodir in $repodirs; do
            wtsub=(${repodir}/*(/N))
            (( ${#wtsub} )) || continue
            (( n_repos++ ))
            _gwt_gather_repo "${repodir:t}" "${wtsub[1]}"
        done
    else
        _gwt_repo_dir || return 1
        _gwt_info "$header"
        _gwt_gather_repo "" "$PWD"
        n_repos=1
    fi

    local summary="${n_total} worktree(s)"
    [[ -n "$all" ]] && summary+=" across ${n_repos} repo(s)"
    summary+=" · ${n_dirty} dirty · ${n_stale} stale"
    (( n_removable )) && summary+=" (gwclean would remove ${n_removable})"
    _gwt_info ""
    _gwt_info "${C_DIM}${summary}${C_RESET}"
}

# ---------------------------------------------------------------------------
# Logging — info to stdout; note/warn/error to stderr
# ---------------------------------------------------------------------------

function _gwt_info()  { print -r -- "$*"; }          # normal output, stdout, plain
function _gwt_note()  { _gwt_emit '38;5;208' "$*"; }  # heads-up (orange)
function _gwt_warn()  { _gwt_emit '33'        "$*"; } # warning  (yellow)
function _gwt_error() { _gwt_emit '31'        "$*"; } # failure  (red)

# _gwt_emit <ansi-code> <msg>: print "<cmd>: <msg>" to stderr, colored on a TTY.
function _gwt_emit() {
    local msg="$(_gwt_cmd): $2"
    [[ -t 2 && -z "$NO_COLOR" ]] && msg=$'\e['"$1"'m'"$msg"$'\e[0m'
    print -r -- "$msg" >&2
}

# The public gw command that triggered the message: first non-internal frame.
function _gwt_cmd() {
    local f
    for f in $funcstack; do
        [[ $f == _gwt_* ]] && continue
        print -r -- "$f"; return
    done
    print -r -- gw
}

# ---------------------------------------------------------------------------
# Interactive picker powered by fzf (used only if installed).
# Control it from your shell: export GWT_PICKER_OPTIONS='--height=60% --preview-window=down'
# ---------------------------------------------------------------------------
: ${GWT_PICKER_OPTIONS:=""}



# Interactively pick worktree(s) of the current repo.
# Returns non-zero if (ESC/^C) or nothing is selected
# _gwt_pick [-m] [--skip-current] [-p <prompt>]
#   -m              multi-select (prints one path per line)
#   --skip-current  omit the worktree you're standing in (used by gwr)
#   -p <prompt>     fzf prompt label
function _gwt_pick() {
    local multi="" skip_current="" prompt="pick"
    while (( $# )); do
        case "$1" in
            -m)             multi=1 ;;
            --skip-current) skip_current=1 ;;
            -p)             prompt="$2"; shift ;;
        esac
        shift
    done

    _gwt_repo_dir || return 1

    # (path, branch) for every worktree of this repo — same parse as _gwt_gather_repo.
    local -a wt_paths wt_branches
    local line cpath="" cbranch=""
    for line in "${(@f)$(git worktree list --porcelain 2>/dev/null)}"; do
        case "$line" in
            "worktree "*)
                [[ -n "$cpath" ]] && { wt_paths+=("$cpath"); wt_branches+=("$cbranch"); }
                cpath="${line#worktree }"; cbranch="(detached)" ;;
            "branch refs/heads/"*) cbranch="${line#branch refs/heads/}" ;;
        esac
    done
    [[ -n "$cpath" ]] && { wt_paths+=("$cpath"); wt_branches+=("$cbranch"); }

    local here=""
    [[ -n "$skip_current" ]] && here="$(git rev-parse --show-toplevel 2>/dev/null)"

    # one bulk query for commit times -> newest-first ordering (matches gws)
    local -A m_ts
    local rec
    for rec in "${(@f)$(git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/heads 2>/dev/null)}"; do
        m_ts[${rec%% *}]="${rec##* }"
    done

    # build "ts \t branch \t path" rows, dropping the current worktree if asked
    local -a rows
    local i path branch ts
    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        path="${wt_paths[$i]}"; branch="${wt_branches[$i]}"
        [[ -n "$here" && "$path" == "$here" ]] && continue
        ts="${m_ts[$branch]:-0}"
        rows+=("${ts}"$'\t'"${branch}"$'\t'"${path}")
    done
    (( ${#rows} )) || { _gwt_warn "no worktrees to pick"; return 1; }

    rows=("${(@On)rows}")                 # newest commit first
    local -a menu
    for line in $rows; do menu+=("${line#*$'\t'}"); done   # drop ts -> "branch \t path"

    local header='enter: select   ctrl-/: toggle preview'
    [[ -n "$multi" ]] && header='enter: confirm   tab: mark   ctrl-/: toggle preview'

    # fzf shows branch (field 1); path (field 2) rides along for preview + return.
    local sel
    sel="$(print -rl -- $menu | fzf --ansi \
        --delimiter=$'\t' --with-nth=1 \
        --height=40% --reverse --border \
        --prompt="$prompt> " \
        --header="$header" \
        --preview 'git -C {2} log --oneline --decorate -20 2>/dev/null; echo; echo "── status ──"; git -C {2} status -s 2>/dev/null' \
        --preview-window='right,50%,border-left' \
        --bind 'ctrl-/:toggle-preview' \
        ${=GWT_PICKER_OPTIONS} \
        ${multi:+--multi})"
    local rc=$?
    (( rc )) && return $rc                 # propagate fzf's code (130 = ESC/^C abort)
    [[ -n "$sel" ]] || return 1

    local sel_line
    for sel_line in "${(@f)sel}"; do print -r -- "${sel_line#*$'\t'}"; done   # emit path(s)
}

function _gwt_is_picker_available() { [[ -t 1 ]] && (( $+commands[fzf] )); }

# Interactively pick a branch that does NOT yet have a worktree; print its short
# name to stdout. Used by a bare `gwa` to create a worktree for an existing branch.
# Lists local heads + origin/* (deduped), newest-commit-first, with the relative
# date inline and author + recent commits in the preview. Returns non-zero on abort
# or when every branch already has a worktree.
function _gwt_pick_branch() {
    _gwt_repo_dir || return 1

    # Branches already checked out in some worktree -> exclude them.
    local -A has_wt
    local line
    for line in "${(@f)$(git worktree list --porcelain 2>/dev/null)}"; do
        [[ "$line" == "branch refs/heads/"* ]] && has_wt[${line#branch refs/heads/}]=1
    done

    local SEP=$'\x1f'
    local -A seen
    local -a rows                          # "ts \t display \t branch \t logref"
    local rec name ts rel_date display

    # local heads (logref = the branch itself)
    for rec in "${(@f)$(git for-each-ref --format="%(refname:short)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)" refs/heads 2>/dev/null)}"; do
        name="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        ts="${rec%%${SEP}*}"; rel_date="${rec#*${SEP}}"
        [[ -z "$name" || -n "${has_wt[$name]}" || -n "${seen[$name]}" ]] && continue
        seen[$name]=1
        display="${name[1,45]}"; display="${(r:45:)display}  ${rel_date}"
        rows+=("${ts}"$'\t'"${display}"$'\t'"${name}"$'\t'"${name}")
    done

    # origin branches without a local counterpart (logref = origin/<name>)
    for rec in "${(@f)$(git for-each-ref --format="%(refname:lstrip=3)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)" refs/remotes/origin 2>/dev/null)}"; do
        name="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        ts="${rec%%${SEP}*}"; rel_date="${rec#*${SEP}}"
        [[ -z "$name" || "$name" == HEAD || -n "${has_wt[$name]}" || -n "${seen[$name]}" ]] && continue
        seen[$name]=1
        display="${name[1,45]}"; display="${(r:45:)display}  ${rel_date}"
        rows+=("${ts}"$'\t'"${display}"$'\t'"${name}"$'\t'"origin/${name}")
    done

    (( ${#rows} )) || { _gwt_warn "no branches without a worktree to pick"; return 1; }

    rows=("${(@On)rows}")                  # newest commit first
    local -a menu
    for line in $rows; do menu+=("${line#*$'\t'}"); done   # drop ts -> "display \t branch \t logref"

    # fzf shows the padded "branch  date" (field 1); branch (2) + logref (3) ride along.
    local sel
    sel="$(print -rl -- $menu | fzf --ansi \
        --delimiter=$'\t' --with-nth=1 \
        --height=40% --reverse --border \
        --prompt='branch> ' \
        --header='enter: create worktree   ctrl-/: toggle preview' \
        --preview 'git log -1 --format="%an · %ar" {3} 2>/dev/null; echo; git log --oneline --decorate -20 {3} 2>/dev/null' \
        --preview-window='right,55%,border-left' \
        --bind 'ctrl-/:toggle-preview' \
        ${=GWT_PICKER_OPTIONS})"
    local rc=$?
    (( rc )) && return $rc                  # propagate fzf's code (130 = ESC/^C abort)
    [[ -n "$sel" ]] || return 1

    local rest="${sel#*$'\t'}"             # drop display -> "branch \t logref"
    print -r -- "${rest%%$'\t'*}"          # emit the short branch name
}
