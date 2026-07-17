GWT_VERSION="1.0.2"

# All worktrees live under $GWT_WORKTREE_DIR/<repo-name>/<branch>.
# Override the base folder by exporting GWT_WORKTREE_DIR before the shell loads.
: ${GWT_WORKTREE_DIR:="$HOME/dev/workspace"}

# Command run inside each new worktree after creation, e.g. 'pnpm install'.
# Default Empty = do nothing.
# Control it from your shell: export GWT_POST_INIT_CMD='pnpm install'
: ${GWT_POST_INIT_CMD:=""}

# Command used to open a worktree ({} = its path; if absent, the path is appended)
# Default is VS Code.
# Control it from your shell: export GWT_OPEN_CMD='cursor {}'
: ${GWT_OPEN_CMD:='code -n && code -a {}'}

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

# Help for the gw worktree commands.
function gwt() {
    case "$1" in
        -v) _gw_info "gwt $GWT_VERSION" ;;
        -h) _gw_help ;;
        *)  _gw_help; echo; _gw_info "version: $GWT_VERSION" ;;
    esac
}

function _gw_help() {
    cat <<EOF
git worktree helpers
Worktrees are created under: $GWT_WORKTREE_DIR/<repo>/<branch>

Usage:
  gwa [-c | -o] <branch> [<start-point>]
      Create a new worktree.
          -c    Copy the "open" command to the clipboard (default)
          -o    Open the worktree in your editor
                (both use \$GWT_OPEN_CMD — VS Code by default)

  gwo [<branch>]                    Open a worktree in your editor. Opens the most recently if <branch> is omitted.
  gwcd [<branch>]                   Change into a worktree. Uses the most recently if <branch> is omitted.

  gwr [-d | -D] <branch> [--force]
      Remove a worktree. The branch is KEPT unless you pass -d/-D.
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
# gwa [-c | -o] <branch> [<start-point>]
#   -c : copy the open-command ($GWT_OPEN_CMD) to the clipboard (default)
#   -o : open the new worktree via $GWT_OPEN_CMD
function gwa() {
    local -a flags pos
    local action="copy"                      # default; add more flags below
    _gw_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -c) action="copy" ;;
            -o) action="open" ;;
            *)  _gw_error "unknown flag: $f"; return 1 ;;
        esac
    done

    local branch="${pos[1]}" startpoint="${pos[2]}"
    if [[ -z "$branch" ]]; then
        _gw_error "usage: [-c|-o] <branch> [<start-point>]"
        return 1
    fi

    local src wt
    _gw_wt_path "$branch" || return 1        # sets wt (and GWT_REPO_DIR)
    src="$(git rev-parse --show-toplevel)"   # current checkout, source of .env

    # If this branch already has a worktree, reuse it instead of failing.
    local existing
    existing="$(_gw_worktree_for_branch "$branch")"
    if [[ -n "$existing" ]]; then
        GWT_LAST="$existing"
        case "$action" in
            open) _gw_info "'$branch' already has a worktree at $existing — opening it"
                  _gw_open "$existing" ;;
            copy) _gw_info "'$branch' already has a worktree at $existing"
                  _gw_copy "$existing" ;;
        esac
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$wt" "$branch" >/dev/null || return 1
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        _gw_note "'$branch' already exists on origin — creating from origin/$branch, not HEAD"
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

    _gw_info "worktree: $wt"

    # Optional shell-controlled bootstrap (e.g. GWT_POST_INIT_CMD='pnpm install').
    if [[ -n "$GWT_POST_INIT_CMD" ]]; then
        ( cd "$wt" && eval "$GWT_POST_INIT_CMD" ) \
            || _gw_error "post-create command failed — worktree kept at $wt"
    fi

    case "$action" in
        copy) _gw_copy "$wt" ;;
        open) _gw_open "$wt" ;;
    esac
}


# Open a worktree via $GWT_OPEN_CMD (VS Code by default).
# With no <branch>, opens the worktree gwa created most recently (this shell).
# gwo [<branch>]
function gwo() {
    local wt
    if [[ -n "$1" ]]; then
        _gw_wt_path "$1" || return 1
    else
        wt="$GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gw_error "usage: <branch>   (or run gwa first, then bare gwo)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gw_error "no worktree at $wt"
        return 1
    fi
    _gw_open "$wt"
}

# cd into a worktree. Without <branch>, cd into recently created worktree.
# gwcd [<branch>]
function gwcd() {
    local wt
    if [[ -n "$1" ]]; then
        _gw_wt_path "$1" || return 1
    else
        wt="$GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gw_error "usage: <branch>   (or run gwa first, then bare gwcd)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gw_error "no worktree at $wt"
        return 1
    fi
    cd "$wt"
}

# Remove the worktree gwa created for <branch>.
# gwr [-d | -D] <branch> [git-worktree-remove flags, e.g. --force]
#   -d : also delete the branch (safe: refuses if it has unmerged commits)
#   -D : also delete the branch (force: even if unmerged)
function gwr() {
    local -a flags pos passthru
    local delete_flag=""             # "" | -d (safe) | -D (force), mirrors git branch
    _gw_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -d|-D) delete_flag="$f" ;;
            *)     passthru+=("$f") ;;   # e.g. --force -> git worktree remove
        esac
    done

    local branch="${pos[1]}"
    if [[ -z "$branch" ]]; then
        _gw_error "usage: [-d|-D] <branch> [--force]"
        return 1
    fi
    local wt
    _gw_wt_path "$branch" || return 1     # sets wt (and GWT_REPO_DIR)

    # Capture the branch checked out in the worktree before removing it, so the
    # delete targets the right ref even when <branch> was given in flattened form.
    local wt_branch=""
    [[ -n "$delete_flag" ]] && wt_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"

    # Explicit flags -> pass straight through. Otherwise: clean (bar seeded files)
    # removes silently with --force; real uncommitted work makes git refuse & warn.
    if (( ${#passthru} )); then
        git worktree remove "$wt" "${passthru[@]}" || return 1
    elif _gw_worktree_is_clean "$wt"; then
        git worktree remove --force "$wt" || return 1
    else
        git worktree remove "$wt" || return 1
    fi

    if [[ -n "$delete_flag" && -n "$wt_branch" && "$wt_branch" != HEAD ]]; then
        # Count commits unique to the branch before deleting (ref still exists).
        local unique
        unique="$(git rev-list --count "HEAD..$wt_branch" 2>/dev/null)"
        if git branch "$delete_flag" "$wt_branch"; then
            # Make the "why did it delete?" self-evident: an empty branch is safe.
            [[ "$unique" == 0 ]] && \
                _gw_info "branch '$wt_branch' had no unique commits — nothing was lost"
        fi
    fi
}

# Remove "stale" worktrees: branch has no commits of its own beyond the default
# branch (merged or never diverged), or its remote branch is gone — then delete those
# branches. Dirty and default-branch worktrees are kept.
# gwclean [-n]
#   -n | --dry-run: preview what would be removed, without removing anything
function gwclean() {
    local -a flags pos
    local dry=""
    _gw_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -n|--dry-run) dry=1 ;;
            *) _gw_error "unknown flag: $f"; return 1 ;;
        esac
    done

    _gw_repo_dir || return 1
    git fetch --prune --quiet origin 2>/dev/null

    local -a wts=(${GWT_REPO_DIR}/*(/N))
    (( ${#wts} )) || { _gw_info "gwclean: no worktrees under $GWT_REPO_DIR"; return 0; }

    local default_br
    default_br="${$(_gw_default_branch)#origin/}"

    local d br x
    local -a removed skipped
    for d in $wts; do
        br="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        [[ -z "$br" || "$br" == HEAD || "$br" == (main|master) || "$br" == "$default_br" ]] && continue
        _gw_branch_stale "$br" || continue
        if ! _gw_worktree_is_clean "$d"; then
            skipped+=("${d:t} ($br) — uncommitted changes")
            continue
        fi
        if [[ -n "$dry" ]]; then
            removed+=("${d:t} ($br)")                       # would remove; don't touch anything
        elif git worktree remove --force "$d" 2>/dev/null; then
            git branch -D "$br" >/dev/null 2>&1
            removed+=("${d:t} ($br)")
        else
            skipped+=("${d:t} ($br) — remove failed")
        fi
    done

    local verb="removed"; [[ -n "$dry" ]] && verb="would remove"
    if (( ${#removed} )); then
        _gw_info "gwclean: $verb ${#removed} worktree(s):"
        for x in $removed; do _gw_info "  $x"; done
    else
        _gw_info "gwclean: nothing to clean"
    fi
    if (( ${#skipped} )); then
        _gw_info "gwclean: skipped ${#skipped}:"
        for x in $skipped; do _gw_info "  $x"; done
    fi
    [[ -n "$dry" ]] && (( ${#removed} )) && _gw_info "gwclean: dry run — nothing removed; run 'gwclean' to apply"
}

# Sets the global GWT_REPO_DIR to $GWT_WORKTREE_DIR/<repo-name> for the current repo.
function _gw_repo_dir() {
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || {
        _gw_error "current directory is not inside a git repository"
        return 1
    }
    common="${common:A}"                     # -> /abs/path/repo/.git
    GWT_REPO_DIR="$GWT_WORKTREE_DIR/${common:h:t}"   # -> $GWT_WORKTREE_DIR/repo
}

# Split argv into caller-local arrays `flags` (tokens starting with -) and
# `pos` (the rest). Caller must declare: local -a flags pos
function _gw_split_args() {
    flags=(); pos=()
    local a
    for a in "$@"; do
        case "$a" in
            -*) flags+=("$a") ;;
            *)  pos+=("$a") ;;
        esac
    done
}

# Set caller-local `wt` to the worktree path for <branch>.
function _gw_wt_path() {
    _gw_repo_dir || return 1
    wt="$GWT_REPO_DIR/${1//\//-}"
}

# Print the path of the worktree that has <branch> checked out, if any.
function _gw_worktree_for_branch() {
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
function _gw_open_cmd() {
    local ph='{}' p
    [[ "$2" == q ]] && p="${(q)1}" || p="\"$1\""
    if [[ "$GWT_OPEN_CMD" == *"$ph"* ]]; then
        print -r -- "${GWT_OPEN_CMD//$ph/$p}"
    else
        print -r -- "$GWT_OPEN_CMD $p"
    fi
}

# Copy a ready-to-run "open" command (per $GWT_OPEN_CMD) to the clipboard.
function _gw_copy() {
    command -v pbcopy >/dev/null || return 0
    _gw_open_cmd "$1" | pbcopy
}

# Open the worktree at <path> using $GWT_OPEN_CMD.
function _gw_open() {
    eval "$(_gw_open_cmd "$1" q)"
}

# True if the worktree at <path> has no real changes.
function _gw_worktree_is_clean() {
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
function _gw_default_branch() {
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
function _gw_branch_stale() {
    local -a C; [[ -n "$2" ]] && C=(-C "$2")
    local base; base="$(_gw_default_branch "$2")"
    [[ -n "$base" ]] && git $C merge-base --is-ancestor "refs/heads/$1" "$base" 2>/dev/null && return 0
    [[ "$(git $C for-each-ref --format='%(upstream:track)' "refs/heads/$1" 2>/dev/null)" == *gone* ]]
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

# gwo / gwcd / gwr: complete names of existing worktrees under $GWT_REPO_DIR.
function _gw_complete_worktrees() {
    _gw_repo_dir 2>/dev/null || return
    local -a wts
    wts=(${GWT_REPO_DIR}/*(/N))   # (/) dirs only, N nullglob
    compadd -- ${wts:t}       # :t -> basenames
}

(( $+functions[compdef] )) && {
    compdef _gw_complete_branches gwa
    compdef _gw_complete_worktrees gwo gwcd gwr
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
function _gw_gather_repo() {
    local label="$1" ctx="$2"
    local base default_br
    base="$(_gw_default_branch "$ctx")"        # computed ONCE per repo (not per worktree)
    default_br="${base#origin/}"

    # Collect (path, branch) for every worktree of this repo; main is listed first.
    local -a wt_paths wt_branches
    local line cpath="" cbranch=""
    for line in "${(@f)$(git -C "$ctx" worktree list --porcelain 2>/dev/null)}"; do
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
    for rec in "${(@f)$(git -C "$ctx" for-each-ref --format=$fmt refs/heads 2>/dev/null)}"; do
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
        for b in "${(@f)$(git -C "$ctx" branch --merged "$base" --format='%(refname:short)' 2>/dev/null)}"; do
            [[ -n "$b" ]] && merged[$b]=1
        done
    fi

    local -a group dirty_flag pids
    local i d branch ts when subject up track a m mark stale is_cur state sync sync_color
    local info restd bt subt fb fs fy fsub row tmpd

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
                a=0; m=0
                [[ "$track" == *"ahead "* ]]  && { a="${track#*ahead }";  a="${a%%[^0-9]*}"; }
                [[ "$track" == *"behind "* ]] && { m="${track#*behind }"; m="${m%%[^0-9]*}"; }
                sync="↑${a:-0} ↓${m:-0}"
                if   (( ${a:-0} > 0 && ${m:-0} > 0 )); then sync_color="$C_DIVERGE"
                elif (( ${a:-0} > 0 ));                then sync_color="$C_OK"
                else                                        sync_color="$C_WARN"; fi
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
        if [[ "$branch" != "(detached)" && "$branch" != "$default_br" && "$branch" != (main|master) ]] \
           && { [[ -n "${merged[$branch]}" ]] || [[ "$sync" == gone ]]; }; then
            stale=1; (( n_stale++ ))
            [[ "$state" == clean ]] && (( n_removable++ ))
        fi

        # marker: current worktree > main worktree > none
        if [[ -n "$here" && "$d" == "$here" ]]; then mark="▶"
        elif (( i == 1 ));                        then mark="⌂"
        else                                           mark=" "; fi

        # pad on plain text, then wrap in color -> columns stay aligned
        bt="${branch[1,20]}";    fb="${(r:20:)bt}"
        subt="${subject[1,30]}"; fsub="${(r:30:)subt}"
        fs="${(r:6:)state}";     fy="${(r:11:)sync}"
        is_cur=""; [[ -n "$here" && "$d" == "$here" ]] && is_cur=1

        if [[ -n "$stale" ]]; then
            # stale rows recede: render plain, then dim the whole line
            row="${C_DIM}$mark ${fb}   ${fs} ${fy} ${fsub}    ${when}  ⚑ stale${C_RESET}"
        else
            [[ "$mark" == "▶" ]] && mark="${C_CUR}▶${C_RESET}"
            [[ "$mark" == "⌂" ]] && mark="${C_MAIN}⌂${C_RESET}"
            [[ -n "$is_cur" ]] && fb="${C_CUR}${fb}${C_RESET}"          # current branch pops
            if [[ "$state" == dirty ]]; then fs="${C_DIRTY}${fs}${C_RESET}"
            else                             fs="${C_DIM}${fs}${C_RESET}"; fi   # clean/unknown recedes
            fy="${sync_color}${fy}${C_RESET}"
            row="$mark ${fb}   ${fs} ${fy} ${fsub}    ${when}"
        fi
        group+=("${ts}"$'\t'"$row")
    done

    group=("${(@On)group}")                       # newest commit first
    (( n_shown++ ))
    (( n_shown > 1 )) && _gw_info ""               # blank line between repo groups
    [[ -n "$label" ]] && _gw_info "${C_BOLD}${label}${C_RESET}"
    local r
    for r in $group; do _gw_info "${r#*$'\t'}"; done
}

function gws() {
    local -a flags pos
    local all=""
    _gw_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -a|--all) all=1 ;;
            *) _gw_error "unknown flag: $f"; return 1 ;;
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
        (( ${#repodirs} )) || { _gw_info "gws: no worktrees under $GWT_WORKTREE_DIR"; return 0; }
        _gw_info "$header"
        local repodir
        local -a wtsub
        for repodir in $repodirs; do
            wtsub=(${repodir}/*(/N))
            (( ${#wtsub} )) || continue
            (( n_repos++ ))
            _gw_gather_repo "${repodir:t}" "${wtsub[1]}"
        done
    else
        _gw_repo_dir || return 1
        _gw_info "$header"
        _gw_gather_repo "" "$PWD"
        n_repos=1
    fi

    local summary="${n_total} worktree(s)"
    [[ -n "$all" ]] && summary+=" across ${n_repos} repo(s)"
    summary+=" · ${n_dirty} dirty · ${n_stale} stale"
    (( n_removable )) && summary+=" (gwclean would remove ${n_removable})"
    _gw_info ""
    _gw_info "${C_DIM}${summary}${C_RESET}"
}

# ---------------------------------------------------------------------------
# Logging — info to stdout; note/warn/error to stderr
# ---------------------------------------------------------------------------

function _gw_info()  { print -r -- "$*"; }          # normal output, stdout, plain
function _gw_note()  { _gw_emit '38;5;208' "$*"; }  # heads-up (orange)
function _gw_warn()  { _gw_emit '33'        "$*"; } # warning  (yellow)
function _gw_error() { _gw_emit '31'        "$*"; } # failure  (red)

# _gw_emit <ansi-code> <msg>: print "<cmd>: <msg>" to stderr, colored on a TTY.
function _gw_emit() {
    local msg="$(_gw_cmd): $2"
    [[ -t 2 && -z "$NO_COLOR" ]] && msg=$'\e['"$1"'m'"$msg"$'\e[0m'
    print -r -- "$msg" >&2
}

# The public gw command that triggered the message: first non-internal frame.
function _gw_cmd() {
    local f
    for f in $funcstack; do
        [[ $f == _gw_* ]] && continue
        print -r -- "$f"; return
    done
    print -r -- gw
}
