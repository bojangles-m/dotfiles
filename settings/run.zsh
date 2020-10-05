if [ -x "$(command -v rbenv)" ]; then
    eval "$(rbenv init -)"
fi

# if [ -x "$(command -v docker-machine)" ]; then
#     docker-machine env default
# fi

# NVM a version manager for node.js
export NVM_DIR="~/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

# Create a symlink to the AirPort utility
AIRPORT=/usr/local/bin/airport
if [ ! -h "$AIRPORT" ]; then
    ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
fi
