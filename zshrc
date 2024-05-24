# ~/.zshrc

# ------------------------------------------
# Setup 
# 
# create symlink in your HOME directory
# sudo ln -s ~/(cloud path to shell files)/dotfiles/zshrc ~/.zshrc
# Terminal Preferences choose
#     Profile - Pro
#     Font - Courier 13 pt.
#     Window - Columns: 115 Rows: 80
# ------------------------------------------

# Main folder of ZSH configuration
SHELL_ROOT=($HOME/Mega/MEGA-Stuff/dotfiles)

# ------------------------------------------
# Load settings
# ------------------------------------------
SETTINGS=($SHELL_ROOT/settings)
source $SETTINGS/terminal.colors.zsh
source $SETTINGS/paths.zsh
source $SETTINGS/run/run.zsh
source $SETTINGS/options.zsh
source $SETTINGS/keybindings.zsh

# ------------------------------------------
# Load prompt theme
# ------------------------------------------
THEMES_ROOT=($SHELL_ROOT/themes)
source $THEMES_ROOT/theme.zsh

# ------------------------------------------
# Load all of plugin files
# ------------------------------------------
PLUGINS=($SHELL_ROOT/plugins)

typeset -U plugins
plugins=($PLUGINS/**/*)

for file in ${plugins}
do
  source $file
done

# ------------------------------------------
# Important
# ------------------------------------------
export PNPM_HOME="/Users/bojanmazej/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
