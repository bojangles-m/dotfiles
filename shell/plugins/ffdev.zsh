tmux_attach_or_switch() {
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$1"
  else
    tmux attach -t "$1"
  fi
}

ffdev() {
  if tmux has-session -t ffdev 2>/dev/null; then
    if [[ "$1" == "rb" ]]; then
      echo "Restarting web-app in right-bottom pane..."
      tmux kill-pane -t ffdev:0.2 \; \
        split-window -v -t ffdev:0.1 \; \
        send-keys -t ffdev:0.2 "cd ~/dev/web-app && pnpm dev" C-m \; \
        select-pane -t ffdev:0.0 \; \
        send-keys -t ffdev:0.0 C-m
      return
    elif [[ "$1" == "kill" ]]; then
      echo "Killing entire session..."
      tmux kill-session -t ffdev 2>/dev/null
      return
    fi

    # Attach/switch to existing session and cd into web-app dir
    tmux select-pane -t ffdev:0.0 \; \
      send-keys -t ffdev:0.0 "cd ~/dev/web-app" C-m

    tmux_attach_or_switch ffdev
    return
  fi

  # kill session if exists to start fresh one
  tmux kill-session -t ffdev 2>/dev/null

  # Run SSO login first (interactive, before tmux)
  aws sts get-caller-identity &>/dev/null || aws sso login

  # Session doesn't exist: create new layout
  tmux new-session -d -s ffdev

  # Left pane: CLI
  tmux select-pane -t ffdev:0.0
  tmux send-keys -t ffdev:0.0 "clear" C-m
  tmux send-keys -t ffdev:0.0 "cd ~/dev/web-app" C-m

  # Top-Right pane: ffy serve
  tmux split-window -h -t ffdev
  tmux send-keys -t ffdev:0.1 "ffy serve" C-m

  # Bottom-Right pane: web-app
  tmux split-window -v -t ffdev:0.1
  tmux send-keys -t ffdev:0.2 "cd ~/dev/web-app && pnpm dev" C-m

  # Make left pane active
  tmux select-pane -t ffdev:0.0

  # Attach or switch
  tmux_attach_or_switch ffdev
}

ffdevba() {
  if tmux has-session -t ffdev-ba 2>/dev/null; then
    if [[ "$1" == "kill" ]]; then
      echo "Killing entire session..."
      tmux kill-session -t ffdev-ba
      return
    fi

    tmux_attach_or_switch ffdev-ba
    return
  fi

  # kill session if exists to start fresh one
  tmux kill-session -t ffdev-ba 2>/dev/null

  # Run SSO login first (interactive, before tmux)
  aws sts get-caller-identity &>/dev/null || aws sso login

  # Session doesn't exist: create new layout
  tmux new-session -d -s ffdev-ba

  # Left pane: Brand assistant
  tmux send-keys -t ffdev-ba:0.0 "clear" C-m
  tmux send-keys -t ffdev-ba:0.0 "cd ~/dev/brand_assistant && gpl origin main && pnpm dev" C-m

  # Right pane: MCP server
  tmux split-window -h -t ffdev-ba:0.0
  tmux send-keys -t ffdev-ba:0.1 "cd ~/dev/frontify-mcp-server && export NODE_EXTRA_CA_CERTS=$HOME/.ffy-cli/tls/ca.crt && pnpm install && pnpm dev" C-m

  # Make left pane active
  tmux select-pane -t ffdev-ba:0.0

  # Attach or switch
  tmux_attach_or_switch ffdev-ba
}

ffdev2() {
  local session="ffdev"

  if [[ "$1" == "kill" ]]; then
    tmux kill-session -t $session 2>/dev/null
    return
  fi

  # create session if missing
  if ! tmux has-session -t $session 2>/dev/null; then
    aws sts get-caller-identity &>/dev/null || aws sso login
    tmux new-session -d -s $session -n shell
    tmux send-keys -t $session:0 "cd ~/dev" C-m
  fi

  case "$1" in

    web)
      if ! tmux list-windows -t $session | grep -q web; then
        tmux new-window -t $session -n web

        tmux send-keys -t $session:web "cd ~/dev/web-app" C-m

        tmux split-window -h -t $session:web
        tmux send-keys -t $session:web.1 "ffy serve" C-m

        tmux split-window -v -t $session:web.1
        tmux send-keys -t $session:web.2 "cd ~/dev/web-app && pnpm dev" C-m

        tmux select-pane -t $session:web.0
      fi

      tmux select-window -t $session:web
      ;;

    ba)
      if ! tmux list-windows -t $session | grep -q brand; then
        tmux new-window -t $session -n brand

        # left pane
        tmux send-keys -t $session:brand.0 \
          "cd ~/dev/brand_assistant && gpl origin main && pnpm dev" C-m

        # # create right pane
        # tmux split-window -h -t $session:brand.0
          
        # # right pane (MCP)
        # tmux send-keys -t $session:brand.1 \
        #   tmux send-keys -t ffdev-ba:0.1 "cd ~/dev/frontify-mcp-server && export NODE_EXTRA_CA_CERTS=$HOME/.ffy-cli/tls/ca.crt && pnpm install && pnpm dev" C-m

        tmux select-pane -t $session:brand.0
      fi

      tmux select-window -t $session:brand
      ;;
  esac

  tmux_attach_or_switch $session
}
