alias daemon="app-server php application/cli/daemon.php"
alias worker-image="worker php application/cli/daemons/image.php"
alias worker-video="worker php application/cli/daemons/video.php"

alias idx-run='indexer php application/cli/daemons/indexer.php'
alias idx-reindex='app-server php application/cli/search/reindex_by_account.php'
alias idx-setup='app-server php application/cli/search/setup_index.php'

# Deptrac: Main goal was to prevent misusage of module’s architecture.
# deptrac.yaml is checking the structure of modules
# deptrac-legacy.yaml how modules in legacy architecture are used.
# You can run Deptrac locally with commands:
alias dpt=app-server php composer.phar run deptrac
alias dptl=app-server php composer.phar run deptrac:legacy

alias test="pnpm test"
alias test:w="pnpm test:unit:watch"
alias test:c:w="pnpm test:coverage:watch"

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
