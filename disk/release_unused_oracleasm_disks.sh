#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

Tous les disques non utilisés du Grid sont rendu au système.
Les disques non utilisés sont ceux visible par la commande kfod.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

#ple_enable_log -params $PARAMS

must_be_user root

# Contiendra tous les disques a effacer.
typeset	-a	device_list

function delete_oracleasm_oracle_disks
{
	line_separator
	# afd_label vaut toujours AFD
	while IFS=':' read afd_label disk_label
	do
		[ x"$disk_label" == x ] && continue || true
		info "Delete disk $disk_label"
		exec_cmd oracleasm deletedisk $disk_label
		LN
	done<<<"$(kfod | grep "ORCL:.*" | awk '{ print $4 }')"
}

function oracleasm_rescan_other_nodes
{
	if [ $gi_count_nodes -gt 1 ]
	then
		line_separator
		info "Refresh other nodes."
		execute_on_other_nodes '. .bash_profile && oracleasm scandisks'
		LN
	fi
}

delete_oracleasm_oracle_disks

oracleasm_rescan_other_nodes

info "On server $infra_hostname use script ~/plescripts/san/delete_db_lun.sh"
info "to delete disks."
LN
