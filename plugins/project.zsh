alias daemon="app-server php application/cli/daemon.php"
alias worker-image="worker php application/cli/daemons/image.php"
alias worker-video="worker php application/cli/daemons/video.php"

alias idx-run='indexer php application/cli/daemons/indexer.php'
alias idx-reindex='app-server php application/cli/search/reindex_by_account.php'
alias idx-setup='app-server php application/cli/search/setup_index.php'

alias test:w="pnpm test:unit:watch"
