#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset		db=undef
typeset		vmGroup
typeset		clone_master_parameters

typeset -r	str_usage=\
"Usage : $ME
	-db=name
	[-vmGroup=name]
	-other parameters transmit to clone_master.sh

Create all servers.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-vmGroup=*)
			vmGroup=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			clone_master_parameters="$@"
			break
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

for (( inode=1; inode <= max_nodes; ++inode ))
do
	exec_cmd ./clone_master.sh -db=$db -node=$inode -vmGroup=\"$vmGroup\" "$clone_master_parameters"
	LN
done
