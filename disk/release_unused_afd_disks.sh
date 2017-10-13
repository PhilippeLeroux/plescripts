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

# Initialise le tableau device_list avec le nom des disques à 'clearer'
function unlabel_afd_oracle_disks
{
	line_separator
	# afd_label vaut toujours AFD
	while IFS=':' read afd_label disk_label
	do
		[ x"$disk_label" == x ] && continue || true
		device=$(asmcmd afd_lslbl | grep "$disk_label" | awk '{ print $2 }')
		device_list+=( $device )
		info "Unlabel $disk_label on $device"
		exec_cmd asmcmd afd_unlabel $disk_label
		LN
	done<<<"$(kfod | grep "AFD:.*" | awk '{ print $4 }')"

	if [ ${#device_list[*]} -eq 0 ]
	then
		warning "no devices found."
		LN
		exit 0
	fi
}

# Exécute la commande afd_refresh sur tous les autres nœuds.
function afd_refresh_other_nodes
{
	if [ $gi_count_nodes -gt 1 ]
	then
		line_separator
		info "Refresh other nodes."
		execute_on_other_nodes '. .bash_profile && asmcmd afd_refresh'
		LN
	fi
}

function clear_all_devices
{
	line_separator
	for device in ${device_list[*]}
	do
		clear_device $device
		LN
	done
}

unlabel_afd_oracle_disks

afd_refresh_other_nodes

clear_all_devices

info "On server $infra_hostname use script ~/plescripts/san/delete_db_lun.sh"
info "to delete disks."
LN
