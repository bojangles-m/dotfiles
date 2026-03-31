tmux_attach_grouped() {
  local session="$1"
  local target_window="$2"
  local group_session="${session}-$$"

  tmux new-session -d -t $session -s "$group_session"
  if [ -n "$target_window" ]; then
    tmux select-window -t "$group_session:$target_window"
  fi
  tmux set-option -t "$group_session" destroy-unlinked on 2>/dev/null

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$group_session"
  else
    tmux attach -t "$group_session"
  fi
}

ffdev() {
  local session="ffdev"
  local target_window=""

  if [[ "$1" == "kill" ]]; then
    if [ -n "$TMUX" ]; then
      tmux detach-client 2>/dev/null
    fi
    # Kill all sessions in the group (main + grouped)
    local sessions=($(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${session}"))
    for s in "${sessions[@]}"; do
      tmux kill-session -t "$s" 2>/dev/null
    done
    return
  fi

  # create session if missing
  if ! tmux has-session -t "=$session" 2>/dev/null; then
    aws sts get-caller-identity &>/dev/null || aws sso login
    tmux new-session -d -s $session -n shell
    tmux send-keys -t $session:0 "cd ~/dev" C-m
  fi

  # Run SSO login first (interactive, before tmux)
  aws sts get-caller-identity &>/dev/null || aws sso login

  case "$1" in
    web)
      if ! tmux list-windows -t "=$session" | grep -q web; then
        # left pane
        local left_pane=$(tmux new-window -t "=$session" -n web -P -F '#{pane_id}')
        tmux send-keys -t "$left_pane" "cd ~/dev/web-app" C-m

        # Top-Right pane: ffy serve
        local right_top=$(tmux split-window -h -t "$left_pane" -P -F '#{pane_id}')
        # tmux send-keys -t "$right_top" "cd ~/.claude" C-m
        tmux send-keys -t "$right_top" "ffy serve" C-m

        # Bottom-Right pane: web-app
        local right_bottom=$(tmux split-window -v -t "$right_top" -P -F '#{pane_id}')
        # tmux send-keys -t "$right_bottom" "cd ~/dev/worktrees" C-m
        tmux send-keys -t "$right_bottom" "cd ~/dev/web-app && pnpm dev" C-m

        # switch back to left pane
        tmux select-pane -t "$left_pane"
      fi

      target_window="web"
      ;;

    ba)
      if ! tmux list-windows -t "=$session" | grep -q brand; then
        # left pane
        local left_pane=$(tmux new-window -t "=$session" -n brand -P -F '#{pane_id}')
        tmux send-keys -t "$left_pane" "cd ~/dev/brand_assistant && gpl origin main && pnpm dev" C-m

        # right pane
        local right_pane=$(tmux split-window -h -t "$left_pane" -P -F '#{pane_id}')
        tmux send-keys -t "$right_pane" "cd ~/dev/frontify-mcp-server && export NODE_EXTRA_CA_CERTS=$HOME/.ffy-cli/tls/ca.crt && pnpm install && pnpm dev" C-m

        # switch back to left pane
        tmux select-pane -t "$left_pane"
      fi

      target_window="brand"
      ;;
  esac

  tmux_attach_grouped "$session" "$target_window"
}
