#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

typeset -r	all_params="$*"

typeset		rel=undef
typeset		db=undef
typeset		standby=none
typeset -i	ip_node=-1
typeset -i	max_nodes=1
typeset -i	size_dg_gb=$default_size_dg_gb
typeset -i	size_lun_gb=$default_size_lun_gb
typeset		dns_test=yes
typeset		storage=ASM
typeset		luns_hosted_by=$disks_hosted_by
# OH : ORACLE_HOME
typeset		OH_FS=$rac_orcl_fs
[ $OH_FS == default ] && OH_FS=$rdbms_fs_type || true

add_usage "-rel=12.1|12.2"			"Oracle release"
add_usage "-db=name"				"Database name."
add_usage "[-standby=id]"			"ID for standby server."
add_usage "[-max_nodes=1]"			"RAC #nodes"
add_usage "[-OH_FS=$OH_FS]"			"RAC : ORACLE_HOME FS : ocfs2|$rdbms_fs_type."
add_usage "[-luns_hosted_by=$luns_hosted_by]"	"san|vbox"
add_usage "[-size_dg_gb=$size_dg_gb]"			"DG size"
add_usage "[-size_lun_gb=$size_lun_gb]"			"LUNs size"
add_usage "[-no_dns_test]"			"ne pas tester si les IPs sont utilisées."
add_usage "[-storage=$storage]"		"ASM|FS"
add_usage "[-ip_node=node]"			"nœud IP, sinon prend la première IP disponible."

typeset -r str_usage="Usage : $ME\n$(print_usage)"

script_banner $ME $*

#	rac si max_nodes vaut plus de 1
typeset		db_type=std

while [ $# -ne 0 ]
do
	case $1 in
		-size_lun_gb=*)
			size_lun_gb=${1##*=}
			shift
			;;

		-luns_hosted_by=*)
			luns_hosted_by=${1##*=}
			shift
			;;

		-rel=*)
			rel=${1##*=}
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-standby=*)
			standby=$(to_lower ${1##*=})
			shift
			;;

		-ip_node=*)
			ip_node=${1##*=}
			shift
			;;

		-max_nodes=*)
			max_nodes=${1##*=}
			shift
			;;

		-size_dg_gb=*)
			size_dg_gb=${1##*=}
			shift
			;;

		-no_dns_test)
			dns_test=no
			shift
			;;

		-storage=*)
			storage=$(to_upper ${1##*=})
			shift
			;;

		-OH_FS=*)
			OH_FS=$(to_lower ${1##*=})
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
			LN
			exit 1
			;;
	esac
done

exit_if_param_invalid rel "12.1 12.2" "$str_usage"

exit_if_param_undef db	"$str_usage"

exit_if_param_invalid storage "ASM FS" "$str_usage"

[[ $max_nodes -gt 1 && $db_type != rac ]] && db_type=rac || true

[[ $storage == FS ]] && db_type=fs || true

[[ $db_type == rac && $storage == FS ]] && error "RAC on FS not supported." && exit 1

exit_if_param_invalid OH_FS "ocfs2 $rdbms_fs_type" "$str_usage"

if [[ $OH_FS != $rdbms_fs_type && $max_nodes -eq 1 ]]
then
	error  "ORACLE_HOME on $OH_FS only for RAC."
	LN
	exit 1
fi

function validate_config
{
	exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc" >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		cat /tmp/vc
		rm -f /tmp/vc
		exit 1
	fi
	rm -f /tmp/vc
	LN
}

function test_ip_node_used
{
	if [ $dns_test == yes ]
	then
		typeset -r ip_node=$1
		dns_test_if_ip_exist $ip_node
		if [ $? -ne 0 ]
		then
			error "IP $if_pub_network.$ip_node in used."
			exit 1
		fi
	fi
}

function normalyze_node
{
	typeset -ri	num_node=$1

	typeset -ri idx=num_node-1

	server_name=$(printf "srv%s%02d" $db $num_node)
	server_ip=$if_pub_network.$ip_node
	test_ip_node_used $ip_node

	server_private_ip=$if_iscsi_network.$ip_node
	rac_network=${if_rac_network}.${ip_node}
	ip_node=ip_node+1

	if [ $db_type == rac ]
	then
		test_ip_node_used $ip_node
		server_vip=$if_pub_network.$ip_node
	else
		server_vip=undef
		rac_network=undef
	fi
	ip_node=ip_node+1

	echo "${db_type}:${server_name}:${server_ip}:${server_vip}:${rac_network}:${server_private_ip}:${luns_hosted_by}:${OH_FS}:${standby}:${oracle_release}" > $cfg_path/node${num_node}
}

function normalyze_scan
{
	buffer=${db}-scan

	typeset -i node_scan=$ip_node
	for i in $(seq 0 2)
	do
		scan_vip=$if_pub_network.$node_scan
		buffer=$buffer:${scan_vip}
		node_scan=node_scan+1
	done

	echo "$buffer" > $cfg_path/scanvips
}

function adjust_DG_size
{
	#	La taille du DG doit être un multiple de la taille des LUNs.
	typeset -i dg_lun_count=$(( size_dg_gb /  size_lun_gb))
	if [ $dg_lun_count -lt $default_minimum_lun ]
	then
		dg_lun_count=$default_minimum_lun
		typeset	-i corrected_size_dg_gb=$(( size_lun_gb *  dg_lun_count ))
		while [ $corrected_size_dg_gb -lt $size_dg_gb ]
		do
			corrected_size_dg_gb=$(( corrected_size_dg_gb + size_lun_gb ))
		done
		size_dg_gb=$corrected_size_dg_gb
		info "Adjust DG size to ${size_dg_gb}Gb : minimum $default_minimum_lun LUNs of ${size_lun_gb}Gb per DG"
		LN
	fi
}

#	Les n° de disques n'ont plus de sens, ils sont conservés car ils permettent
#	de déterminer le nombre de disques nécessaire.
function normalyse_disks
{
	typeset -i i_lun=1

	if [ $db_type == rac ]
	then
		echo "CRS:6:1:3" > $cfg_path/disks
		i_lun=4
		if [ "$oracle_release" == "12.2.0.1" ]
		then
			echo "GIMR:4:4:13" >> $cfg_path/disks
			i_lun=14
		fi
	fi

	adjust_DG_size

	typeset	-i	max_luns=$(( size_dg_gb / size_lun_gb ))
	typeset	-i	corrected_size_dg_gb=$(( size_lun_gb *  max_luns ))
	if [ $corrected_size_dg_gb -lt $size_dg_gb ]
	then
		while [ $corrected_size_dg_gb -lt $size_dg_gb ]
		do
			corrected_size_dg_gb=$(( corrected_size_dg_gb + size_lun_gb ))
		done
		max_luns=$(( corrected_size_dg_gb / size_lun_gb ))
		info "DG size will be $max_luns LUNs * ${size_lun_gb}Gb = ${corrected_size_dg_gb}Gb (greater than ${size_dg_gb}Gb requested)"
		LN
	fi

	if [ $storage == FS ]
	then
		typeset	buffer="FSDATA:${size_lun_gb}:$i_lun:"
	else
		typeset	buffer="DATA:${size_lun_gb}:$i_lun:"
	fi
	typeset	-i	last_lun=i_lun+max_luns-1
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks

	if [ $storage == FS ]
	then
		buffer="FSFRA:${size_lun_gb}:$i_lun:"
	else
		buffer="FRA:${size_lun_gb}:$i_lun:"
	fi
	last_lun=i_lun+max_luns-1
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks
}

# Init variable ip_node
function set_ip_node
{
	# Détermine le nombre d'adresse IPs à obtenir.
	if [ $max_nodes -eq 1 ]
	then # Standalone server.
		typeset -ri ip_range=1
	else # RAC server.
		typeset -ri ip_range=max_nodes*2+3	# 2 IP / nodes, 3 SCAN IP
	fi

	# Demande '$ip_range' adresses IPs consécutives.
	ip_node=$(ssh $dns_conn "~/plescripts/dns/get_free_ip_node.sh -range=$ip_range")
}

function next_instructions
{
	if [ "$standby" != none ]
	then
		if [ -d $cfg_path_prefix/$standby ]
		then # Le premier serveur existe
			typeset -r vmGroup="/DG $(initcap $standby) et $(initcap $db)"
		else
			typeset -r vmGroup="/DG $(initcap $db) et $(initcap $standby)"
		fi
		if [ $max_nodes -eq 1 ]
		then
			info "Execute : ./clone_master.sh -db=$db -vmGroup=\"$vmGroup\""
		else
			info "Execute : ./create_database_servers.sh -db=$db -vmGroup=\"$vmGroup\""
		fi
	else
		if [ $max_nodes -eq 1 ]
		then
			info "Execute : ./clone_master.sh -db=$db"
		else
			info "Execute : ./create_database_servers.sh -db=$db"
		fi
	fi
	LN
}

if [ "$rel" != "${oracle_release%.*.*}" ]
then
	info "Update Oracle Release"
	exec_cmd ~/plescripts/switch_ora_release.sh -rel=$rel

	info "Call with local config updated."
	exec_cmd $ME $all_params
	LN
	exit 0
fi

validate_config

line_separator
typeset -r	cfg_path=$cfg_path_prefix/$db
if [ -d $cfg_path ]
then # La configuration pour $db existe déjà !
	confirm_or_exit "$cfg_path exists, remove :"
	exec_cmd rm -rf $cfg_path
fi
exec_cmd mkdir $cfg_path
LN

[ $ip_node -eq -1 ] && set_ip_node || true

for (( inode=1; inode <= max_nodes; ++inode ))
do
	normalyze_node $inode
done

[ $db_type == rac ] && normalyze_scan || true

normalyse_disks

./show_info_server.sh -db=$db

next_instructions

if [ "$standby" != none ] && cfg_exists $standby use_return_code >/dev/null 2>&1
then
	cfg_load_node_info $standby 1
	if [ "$oracle_release" != "$cfg_orarel" ]
	then
		warning "Dataguard different release : $db $oracle_release, $standby $cfg_orarel"
		LN
	fi
fi

if [[ $rel == "12.2" && $max_nodes -gt 1 ]]
then
	if [[ $OH_FS != ocfs2 ]]
	then
		warning "Advice with RAC $rel add option : -OH_FS=ocfs2"
		LN
	fi
fi
