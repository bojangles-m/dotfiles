##############################################################################
# PATH stuff
##############################################################################

for p in '/usr/local/sbin' '/usr/sbin' '/sbin' '/bin' '/usr/bin' '/usr/local/bin' "${HOME}/bin"
do
    PATH="${p}:${PATH}"
done

# Pick up GIT binaries
if [[ -d "/usr/local/git/bin" ]]
then
    PATH=/usr/local/git/bin:$PATH
fi

# Pick up NPM-installed binaries
if [[ -d "/usr/local/share/npm/bin" ]]
then
    PATH=/usr/local/share/npm/bin:$PATH
fi

# Deduplicate entries in PATH
typeset -U PATH

export PATH