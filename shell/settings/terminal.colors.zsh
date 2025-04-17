# enables coloring of terminal
export CLICOLOR=1

# This string is a concatenation of pairs of the format fb, where f is the foreground color and b is the background color.
# The order of the attributes are as follows:
# 1.   directory
# 2.   symbolic link
# 3.   socket
# 4.   pipe
# 5.   executable
# 6.   block special
# 7.   character special
# 8.   executable with setuid bit set
# 9.   executable with setgid bit set
# 10.  directory writable to others, with sticky bit
# 11.  directory writable to others, without sticky bit
# Black | B=Red | C=Green | D=Yellow | E=Blue | F=Purple | G=Cyan | X=White
# Capital letters means BOLD
export LSCOLORS=cxfxcxDxbxegedxbxgxcxd