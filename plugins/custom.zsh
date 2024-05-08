# For diagnosing Wi-Fi related issues, use the Wireless Diagnostics app or wdutil command line tool.
alias wdinfo='sudo wdutil info'

# Copy the working dir to the clipboard
alias cpwd='pwd|xargs echo -n|pbcopy'

# `wifi on` to turn wifi on, and `wifi off` to turn it off
alias wifi="networksetup -setairportpower $(networksetup -listallhardwareports | grep -A 2 'Hardware Port: Wi-Fi' | grep 'Device:' | awk '{print $2}')"

# Network connections list
alias netlist="networksetup -listallhardwareports"

# Print local IPs
alias ip4=ipconfig getifaddr en0
alias mac=ifconfig en0 | awk '/ether / {print $2}'

# public IP address
alias ipPublic="curl http://ipecho.net/plain; echo"

# Visual Studo Code 
alias vscode="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"

