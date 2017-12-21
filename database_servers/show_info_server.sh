#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage="Usage : $ME -db=name"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

[[ $db == undef && x"$ID_DB" == x ]] && db=$ID_DB
exit_if_param_undef db "$str_usage"

cfg_exists $db

typeset -ri max_nodes=$(cfg_max_nodes $db)

#	$1	node number
function print_node
{
	typeset	-ri inode=$1

	cfg_load_node_info $db $inode

	if [ $inode -eq 1 ]
	then
		info "Oracle Release : $cfg_orarel"
		if [ x"$cfg_master_name" != x ]
		then
			info "Master : $cfg_master_name"
		fi
		LN

		info -n "LUNs hosted by : "
		case $cfg_luns_hosted_by in
			vbox)
				info -f "VirtualBox"
				;;
			san)
				info -f "$infra_hostname protocol iSCSI"
				;;
		esac

		info -n "ORACLE_HOME FS : $cfg_oracle_home"
		case $cfg_oracle_home in
			ocfs2)
				info -f " : heartbeat on $if_iscsi_name/$cfg_iscsi_ip"
				;;
			*)
				LN
		esac
		LN
	fi

	if [[ $cfg_dataguard == yes && $inode -eq 1 ]]
	then
		info "Dataguard 2 members."
		LN
	fi

	case $cfg_db_type in
		rac)
			info "Node #$inode RAC :"
			;;

		std|fs)
			info "Node #$inode standalone :"
			;;
	esac

	info "    Server name     ${cfg_server_name}       : ${cfg_server_ip}"

	if [ $cfg_db_type == rac ]
	then
		info "    VIP             ${cfg_server_name}-vip   : ${cfg_server_vip}"
		info "    Interco RAC     ${cfg_server_name}-rac   : ${cfg_rac_network}"
	fi

	case $cfg_luns_hosted_by in
		san)
			info "    Interco iSCSI   ${cfg_server_name}-iscsi : ${cfg_iscsi_ip}"
			;;

		vbox)
			info "    Disks hosted by VirtualBox ($if_iscsi_name unused for LUNs)"
			;;

		*)
			warning "    Old cfg file."
			;;
	esac
}

function print_scan
{
	typeset -r	file=$1

	IFS=':' read scan_name vip1 vip2 vip3 < $file
	info "scan : $scan_name"
	info "       $vip1"
	info "       $vip2"
	info "       $vip3"
}

function print_disks
{
	typeset -r	file=$1
	exit_if_file_not_exists $file

	typeset -r upper_db=$(to_upper $db)
	typeset -i no_first_disk
	typeset -i no_last_disk
	typeset -i no_disks
	while IFS=':' read dg_name disk_size no_first_disk no_last_disk
	do
		typeset	-i total_disks=$(( no_last_disk - no_first_disk + 1 ))

		if [[ $cfg_dataguard == yes || $max_nodes -eq 1 ]] && [[ $cfg_db_type == fs ]]
		then # Base single sur FS.
			if [ ${dg_name:2} == "DATA" ]
			then
				info -n "DATA : $ORCL_FS_DATA"
			else
				info -n "FRA  : $ORCL_FS_FRA"
			fi
			info -f " size $(( total_disks * disk_size ))Gb ($total_disks disks)."
		else
			info "DG $dg_name :"
			typeset	-i	size=0
			typeset	-i	left_padding=0
			typeset		disk_name
			typeset		label
			typeset		idisk
			for (( idisk = no_first_disk; idisk <= no_last_disk; ++idisk ))
			do
				disk_name=$(printf "S1DISK%s%02d" $upper_db $idisk)
				label=$(printf "    %s  %dGb\n" $disk_name $disk_size)
				info "$label"
				left_padding=${#disk_name}+4 # 4 == begining spaces
				size=size+disk_size
			done
			info "$(printf "%${left_padding}s %02dGb" "$total_disks disks" $size)"
		fi
		LN
	done < $file
}

for (( inode=1; inode <= max_nodes; ++inode ))
do
	print_node $inode
	LN
done

if [ -f $cfg_path_prefix/$db/scanvips ]
then
	print_scan $cfg_path_prefix/$db/scanvips
	LN
fi

print_disks $cfg_path_prefix/$db/disks
