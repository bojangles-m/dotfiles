# ~/.zshrc

# ------------------------------------------
# Setup 
# 
# create symlink in your HOME directory
# sudo ln -s dotfiles/zshrc ~/.zshrc
# ------------------------------------------
# Main folder of your ZSH configuration with zshrc and folder zsh
ZSH=dotfiles

# ------------------------------------------
# Load all of our zsh files
# ------------------------------------------
typeset -U config_files
config_files=($HOME/$ZSH/zsh/**/*)

for file in ${config_files}
do
  source $file
done

# ------------------------------------------
# create symbolic link for Projects
# in /var/www
# ------------------------------------------
function www() {
  destination="/var/www/$@"
  source=$PWD

  base=$(basename $source)
  symlink="$destination$base"

  # check if /var/www folder exists
  [ ! -d $dest ] && { echo "Error: $destination - Directory does not exists."; return; }

  # check if symlink already exists
  [ -L $symlink ] && { echo "Error: $symlink - Symlink already exists."; return; }

  # reading the input line 
  read "?Do you want to create symlink: [ $symlink ] (y/n)?: " line

  # Check if the input is y|Y
  if [[ "$line" = "y" || "$line" = "Y" ]]; then
    # create symlink
    sudo ln -s $source $destination
    
    [ -L $symlink ] && echo "Symlink was created."
  fi
}
