#/bin/bash


# vim: ts=4:sw=4

#   Exécuter ce scripts après qu'un des noeuds ait exécuté :
#		oracleasm_discovery_first_node.sh

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

exec_cmd "~/plescripts/disk/discovery_target.sh"

pause_in_secs 2
LN

line_separator
exec_cmd "oracleasm scandisks"

exit 0
