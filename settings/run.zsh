if [ -x "$(command -v rbenv)" ]; then
    eval "$(rbenv init -)"
fi

if [ -x "$(command -v docker-machine)" ]; then
    eval "$(docker-machine env default)"
fi

# NVM a version manager for node.js
export NVM_DIR="~/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm