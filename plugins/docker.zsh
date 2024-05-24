# Use dco as alias for docker-compose, since dc on *nix is 'dc - an arbitrary precision calculator'
# https://www.gnu.org/software/bc/manual/dc-1.05/html_mono/dc.html

alias dco='docker compose'
alias dcb='docker compose build'
alias dcup='docker compose up'
alias dcbup='docker compose up --build'
alias dcr='docker compose run'
alias dcstop='docker compose stop'
alias ddown='docker compose down'
alias dce='docker compose exec'
alias dcrestart='docker compose restart'
alias dcrm='docker compose rm'
alias dcl='docker compose logs'
alias dclf='docker compose logs -f'
alias dcpull='docker compose pull'
alias dcstart='docker compose start'
alias dck='docker compose kill'

alias dps='docker ps -a'
alias dimg="docker image ls"
alias dl='docker login --username'

alias dcrenew='docker compose up --build --pull=always --remove-orphans --renew-anon-volumes'
