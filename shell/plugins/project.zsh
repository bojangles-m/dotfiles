alias daemon="ffy exec app-server 'php application/cli/daemon.php'"

alias worker-image="ffy exec worker 'php /var/www/worker/application/cli/daemons/image.php'"
alias worker-video="ffy exec worker 'php /var/www/worker/application/cli/daemons/video.php'"

alias idx-run="ffy exec indexer 'php application/cli/daemons/indexer.php'"
alias idx-setup="ffy exec app-server 'php application/cli/search/setup_index.php'"
alias idx-reindex="ffy exec app-server 'php application/cli/search/reindex_by_account.php'"
alias idx-reindex-vectors="ffy exec app-server 'php /var/www/app-server/application/cli/search/reindex_by_account.php --with-vectors'" 

alias test="pnpm test"
alias test:w="pnpm test:unit:watch"
alias test:c:w="pnpm test:coverage:watch"
