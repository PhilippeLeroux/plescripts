#/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r initiator_name=$(cat /etc/iscsi/initiatorname.iscsi | cut -d'=' -f2)
typeset -r disk_prefix="ip-${san_ip_priv}:3260-iscsi-${initiator_name}-lun-"

line_separator
info "Discovery portal $san_ip_priv"
exec_cmd iscsiadm --mode discovery --type sendtargets --portal $san_ip_priv
LN
# BUG ?	Tous les initiators sont vus, je supprime ceux que je ne veux pas en
#		attendant de trouver mieux
fake_exec_cmd "iscsiadm -m node -P 0 | grep -v $initiator_name"
iscsiadm -m node -P 0 | grep -v $initiator_name |\
while read portal other_initiator_name
do
	exec_cmd iscsiadm -m node --op delete --targetname $other_initiator_name
done
LN

info "Connect to $initiator_name"
exec_cmd iscsiadm -m node -T $initiator_name --portal $san_ip_priv -l
LN

info "New disks : ls /dev/disk/by-path/${disk_prefix}*"
LN

#Devrait appeler setting_iscsi_chap_auth.sh, mais l'authentification ne marche pas.
