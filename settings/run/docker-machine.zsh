if [ -x "$(command -v docker-machine)" ]; then
    docker-machine env default
fi