# ~/.zshrc

# ------------------------------------------
# Setup 
# 
# create symlink in your HOME directory
# sudo ln -s dotfiles/zshrc ~/.zshrc
# ------------------------------------------

# Main folder of ZSH configuration
SHELL=($HOME/dotfiles)

# ------------------------------------------
# Load settings
# ------------------------------------------
SETTINGS=($SHELL/settings)

source $SETTINGS/run.zsh
source $SETTINGS/terminal.colors.zsh
source $SETTINGS/paths.zsh
source $SETTINGS/options.zsh
source $SETTINGS/keybindings.zsh

# ------------------------------------------
# Load prompt theme
# ------------------------------------------
THEMES=($SHELL/themes)
load_theme=second.theme.zsh
source $THEMES/$load_theme

# ------------------------------------------
# Load all of plugin files
# ------------------------------------------
PLUGINS=($SHELL/plugins)

typeset -U plugins
plugins=($PLUGINS/**/*)

for file in ${plugins}
do
  source $file
done
