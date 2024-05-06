# Show current airport status:
alias airinfo='airport -I'

# Copy the working dir to the clipboard
alias cpwd='pwd|xargs echo -n|pbcopy'

# `wifi on` to turn wifi on, and `wifi off` to turn it off
alias wifi="networksetup -setairportpower $(networksetup -listallhardwareports | grep -A 2 'Hardware Port: Wi-Fi' | grep 'Device:' | awk '{print $2}')"

# Network connections list
alias netlist="networksetup -listallhardwareports"

# Print local IPs
alias ip4="ifconfig | grep -w inet"
alias ip6="ifconfig | grep -w inet6"

# get your IP address
alias myip="curl http://ipecho.net/plain; echo"

# quick conversion to pdf
# alias pdf='libreoffice --headless --invisible --convert-to pdf'

# Disk usage
alias da='du -sch'

# SL for Visual Studo Code 
alias vscode="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"

