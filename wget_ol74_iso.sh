#!/bin/sh

#
# Generated onSat Sep 02 06:49:40 PDT 2017# Start of user configurable variables
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

# Contact osdc site so that we can get SSO Params for logging in
SSO_RESPONSE=`$WGET --user-agent="Mozilla/5.0" --no-check-certificate https://edelivery.oracle.com/osdc/faces/SearchSoftware 2>&1|grep Location`

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




  $WGET  --user-agent="Mozilla/5.0" --no-check-certificate --load-cookies=$COOKIE_FILE --save-cookies=$COOKIE_FILE --keep-session-cookies "https://edelivery.oracle.com/osdc/download?fileName=V921569-01.iso&token=eXpaQUlQMVBGcEJNRjRUTUpjNVF0USE6OiF1c2VybmFtZT1FUEQtUEhJTElQUEUuTFJYQEdNQUlMLkNPTSZ1c2VySWQ9NzU4MTgyOSZjYWxsZXI9U2VhcmNoU29mdHdhcmUmY291bnRyeUlkPUZSJmVtYWlsQWRkcmVzcz1waGlsaXBwZS5scnhAZ21haWwuY29tJmZpbGVJZD05NTkyODI3MSZhcnU9MjE0NzQ0ODImYWdyZWVtZW50SWQ9MzYzODg3NyZzb2Z0d2FyZUNpZHM9MTQ4NzMyJnBsYXRmb3JtQ2lkcz02MCZwcm9maWxlSW5zdGFuY2VDaWQ9ODI5NDE2JmRvd25sb2FkU291cmNlPXdnZXQmcHJvZmlsZUluc3RhbmNlTmFtZT1PcmFjbGUgTGludXggNy40LjAuMC4wIGZvciB4ODYgNjQgYml0JnBsYXRmb3JtTmFtZT14ODYgNjQgYml0Jm1lZGlhQ2lkPTgyOTI1OSZyZWxlYXNlQ2lkPSZpc1JlbGVhc2VTZWFyY2g9ZmFsc2U" -O $OUTPUT_DIR/V921569-01.iso >> $LOGFILE 2>&1 

