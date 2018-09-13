#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

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

script_start

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

cfg_load_node_info $db 1

for (( inode=1; inode <= max_nodes; ++inode ))
do
	exec_cmd ./clone_master.sh	-db=$db -node=$inode -vmGroup=\"$vmGroup\"	\
								-skip_instructions							\
								"$clone_master_parameters"
	LN
done

script_stop $ME $db
LN

if [ "${oracle_release}" == "12.1.0.2" ]
then
	script_name=install_grid12cR1.sh
else # 12cR2 et 18c même script, pour le moment.
	script_name=install_grid12cR2.sh
fi

if [ $cfg_dataguard == no ]
then
	notify "Grid infrastructure can be installed."
	info "./$script_name -db=$db"
	LN
else
	if [ $cfg_db_type == std ]
	then
		notify "Grid infrastructure can be installed."
		info "./$script_name -db=$db -dg_node=1"
		LN
	else
		notify "Oracle software can be installed."
		info "./install_oracle.sh -db=$db -dg_node=1"
		LN
	fi
fi
