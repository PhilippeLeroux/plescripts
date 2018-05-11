#!/bin/sh

#
# Generated onMon Apr 23 03:37:45 PDT 2018# Start of user configurable variables
#
LANG=C
export LANG

# SSO username and password
read -p 'SSO User Name:' SSO_USERNAME
read -sp 'SSO Password:' SSO_PASSWORD


# Path to wget command
WGET=/usr/bin/wget
# Location of cookie file
COOKIE_FILE=/tmp/$$.cookies

# Log directory and file
LOGDIR=.
LOGFILE=$LOGDIR/wgetlog-`date +%m-%d-%y-%H:%M`.log
# Output directory and file
OUTPUT_DIR=.
#
# End of user configurable variable
#

if [ "$SSO_PASSWORD " = " " ]
then
 echo "Please edit script and set SSO_PASSWORD"
 exit
fi

SSO_RESPONSE=`$WGET --user-agent="Mozilla/5.0"  --no-check-certificate https://edelivery.oracle.com/osdc/faces/SoftwareDelivery -O- 2>&1|grep Location`

# Extract request parameters for SSO
SSO_TOKEN=`echo $SSO_RESPONSE| cut -d '=' -f 2|cut -d ' ' -f 1`
SSO_SERVER=`echo $SSO_RESPONSE| cut -d ' ' -f 2|cut -d '/' -f 1,2,3`
SSO_AUTH_URL=/sso/auth
AUTH_DATA="ssousername=$SSO_USERNAME&password=$SSO_PASSWORD&site2pstoretoken=$SSO_TOKEN"

# The following command to authenticate uses HTTPS. This will work only if the wget in the environment
# where this script will be executed was compiled with OpenSSL. Remove the --secure-protocol option
# if wget was not compiled with OpenSSL
# Depending on the preference, the other options are --secure-protocol= auto|SSLv2|SSLv3|TLSv1
$WGET --user-agent="Mozilla/5.0" --secure-protocol=auto --post-data $AUTH_DATA --save-cookies=$COOKIE_FILE --keep-session-cookies $SSO_SERVER$SSO_AUTH_URL -O sso.out >> $LOGFILE 2>&1

rm -f sso.out


$WGET --user-agent="Mozilla/5.0"  --no-check-certificate  --load-cookies=$COOKIE_FILE --save-cookies=$COOKIE_FILE --keep-session-cookies "https://edelivery.oracle.com/osdc/softwareDownload?fileName=V975367-01.iso&token=YzBOaEpiRGh4VG1nSjBnZFhnUkliUSE6OiFmaWxlSWQ9OTk4Njc3NjUmZmlsZVNldENpZD04NjU2MTMmcmVsZWFzZUNpZHM9ODYwNjAwJnBsYXRmb3JtQ2lkcz02MCZkb3dubG9hZFR5cGU9OTU3NjQmYWdyZWVtZW50SWQ9NDM3NzQ1NyZlbWFpbEFkZHJlc3M9cGhpbGlwcGUubHJ4QGdtYWlsLmNvbSZ1c2VyTmFtZT1FUEQtUEhJTElQUEUuTFJYQEdNQUlMLkNPTSZpcEFkZHJlc3M9OTAuMzUuMTMyLjExOCZ1c2VyQWdlbnQ9TW96aWxsYS81LjAgKFgxMTsgTGludXggeDg2XzY0OyBydjo1Mi4wKSBHZWNrby8yMDEwMDEwMSBGaXJlZm94LzUyLjAmY291bnRyeUNvZGU9RlImZGxwQ2lkcz04NjU2NjQ" -O $OUTPUT_DIR/V975367-01.iso>> $LOGFILE 2>&1 

