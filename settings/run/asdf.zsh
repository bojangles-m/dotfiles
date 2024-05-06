# ASDF a version manager for plugins
# source OR . before path makes the same effect
ASDF_DIR="$(brew --prefix asdf)"
if [ -s "$ASDF_DIR/libexec/asdf.sh" ]; then
  . $ASDF_DIR/libexec/asdf.sh
  # . $(brew --prefix asdf)/libexec/asdf.sh
fi
