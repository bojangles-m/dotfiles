##############################################################################
# Zsh options & plugins
##############################################################################

# autoload -U zmv

# autoload -U history-search-end

# Report CPU usage for commands running longer than 10 seconds
# REPORTTIME=10


# history:
setopt inc_append_history   # append history list to the history file (important for multiple parallel zsh sessions!)
setopt share_history        # import new commands from the history file also in other zsh-session
setopt extended_history     # save each command's beginning timestamp and the duration to the history file
setopt hist_ignore_all_dups # If a new command line being added to the history list duplicates an older one, the older command is removed from the list
setopt hist_ignore_space    # remove command lines from the history list when the first character on the line is a space

HISTFILE=$HOME/.zsh_history
HISTSIZE=10000000
SAVEHIST=10000000           # useful for setopt append_history


# setopt auto_cd              # if a command is issued that can't be executed as a normal command,
                            # and the command is the name of a directory, perform the cd command to that directory

# setopt extended_glob        # in order to use #, ~ and ^ for filename generation
                            # grep word *~(*.gz|*.bz|*.bz2|*.zip|*.Z) ->
                            # -> searches for word not in compressed files
                            # don't forget to quote '^', '~' and '#'!

setopt notify               # report the status of backgrounds jobs immediately

setopt hash_list_all        # Whenever a command completion is attempted, make sure
                            # the entire command path is hashed first.

# setopt completeinword       # not just at the end

# setopt nohup                # Don't kill background jobs when shell exits

# setopt auto_pushd           # make cd push the old directory onto the directory stack.

# setopt nonomatch            # try to avoid the 'zsh: no matches found...'

# setopt nobeep               # avoid "beep"ing

# setopt pushd_ignore_dups    # don't push the same dir twice.

# setopt noglobdots           # * shouldn't match dotfiles. ever.

# setopt long_list_jobs       # List jobs in long format, display PID when suspending processes as well

# setopt mark_dirs            # Append a trailing `/' to all directory names resulting from globbing