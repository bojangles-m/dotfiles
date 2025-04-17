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
