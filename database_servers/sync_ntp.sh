#!/bin/sh

BS=$(date)
echo
ntpq -p
S=$SECONDS
systemctl stop ntpd
ntpdate K2
systemctl start ntpd
echo "$(( SECONDS - S )) secs to sync."
echo "Before sync : $BS"
echo "After sync  : $(date)"
