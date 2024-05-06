# Create a symlink to the AirPort utility
AIRPORT=/usr/local/bin/airport
if [ ! -h "$AIRPORT" ]; then
    ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
fi