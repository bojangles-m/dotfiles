alias daemon="app-server php application/cli/daemon.php"
alias worker-image="worker php application/cli/daemons/image.php"
alias worker-video="worker php application/cli/daemons/video.php"

alias idx-run='indexer php application/cli/daemons/indexer.php'
alias idx-reindex='app-server php application/cli/search/reindex_by_account.php'
alias idx-setup='app-server php application/cli/search/setup_index.php'

alias test:w="pnpm test:unit:watch"

# Deptrac: Main goal was to prevent misusage of module’s architecture.
# deptrac.yaml is checking the structure of modules
# deptrac-legacy.yaml how modules in legacy architecture are used.
# You can run Deptrac locally with commands:
alias dpt=app-server php composer.phar run deptrac
alias dptl=app-server php composer.phar run deptrac:legacy
