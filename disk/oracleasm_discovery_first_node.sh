#/bin/bash

#	ts=4 sw=4

#	Une fois que les disques sont disponibles exécuter
#	ce scripts sur un noeud du RAC
#
#	Pour les autres noeuds utiliser oracleasm_discovery_other_nodes.sh

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

cd ~/plescripts/disk

exec_cmd "./discovery_target.sh"

exec_cmd "./create_partitions_on_new_disks.sh"

line_separator
exec_cmd "./create_oracle_disk_on_new_part.sh"

exit 0
