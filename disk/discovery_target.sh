#/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r initiator_name=$(cat /etc/iscsi/initiatorname.iscsi | cut -d'=' -f2)
typeset -r disk_prefix="ip-${san_ip_priv}:3260-iscsi-${initiator_name}-lun-"

line_separator
info "Discovery portal $san_ip_priv"
exec_cmd iscsiadm --mode discovery --type sendtargets --portal $san_ip_priv
LN

info "Connect to $initiator_name"
exec_cmd iscsiadm -m node -T $initiator_name --portal $san_ip_priv -l
LN

info -n "Wait : "; pause_in_secs 5; LN

exec_cmd "ls /dev/disk/by-path/${disk_prefix}*"

# Permet de voir les nouvelles luns.
# scsiadm -m node --rescan
