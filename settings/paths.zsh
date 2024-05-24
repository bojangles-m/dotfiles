##############################################################################
# PATH stuff
##############################################################################

for p in '/usr/local/sbin' '/usr/sbin' '/sbin' '/bin' '/usr/bin' '/usr/local/bin' "${HOME}/bin"
do
    PATH="${p}:${PATH}"
done

# Pick up NPM-installed binaries
if [[ -d "/usr/local/share/npm/bin" ]] then
    PATH=/usr/local/share/npm/bin:$PATH
fi

# Deduplicate entries in PATH
typeset -U PATH

export PATH

# set mysql@5.7 in your PATH
export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"

export PATH="/usr/local/opt/php@7.4/bin:$PATH"
export PATH="/usr/local/opt/php@7.4/sbin:$PATH"

export PATH="$PATH:$HOME/Frontify/docker/bin"
