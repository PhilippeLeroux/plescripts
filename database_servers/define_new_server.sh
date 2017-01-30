#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

# OH : ORACLE_HOME
typeset OH_FS=$rac_orcl_fs
[ $OH_FS == default ] && OH_FS=$rdbms_fs_type || true

add_usage "-db=name"				"Database name."
add_usage "[-max_nodes=1]"			"RAC #nodes"
add_usage "[-OH_FS=$OH_FS]"			"RAC : ORACLE_HOME FS : ocfs2|$rdbms_fs_type."
add_usage "[-luns_hosted_by=$disks_hosted_by]"	"san|vbox"
add_usage "[-size_dg_gb=$default_size_dg_gb]"	"DG size"
add_usage "[-size_lun_gb=$default_size_lun_gb]" "LUNs size"
add_usage "[-no_dns_test]"			"ne pas tester si les IPs sont utilisées."
add_usage "[-usefs]"				"ne pas utiliser ASM mais un FS."
add_usage "[-ip_node=node]"			"nœud IP, sinon prend la première IP disponible."

typeset -r str_usage="Usage : $ME\n$(print_usage)"

script_banner $ME $*

typeset		db=undef
typeset -i	ip_node=-1
typeset -i	max_nodes=1
typeset -i	size_dg_gb=$default_size_dg_gb
typeset -i	size_lun_gb=$default_size_lun_gb
typeset		dns_test=yes
typeset 	usefs=no
typeset		luns_hosted_by=$disks_hosted_by

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

		-db=*)
			db=$(to_lower ${1##*=})
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

		-usefs)
			usefs=yes
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

exit_if_param_undef db	"$str_usage"

[ $max_nodes -gt 1 ] && [ $db_type != rac ] && db_type=rac

[ $db_type == rac ] && [ $usefs == yes ] && error "RAC on FS not supported." && exit 1

exit_if_param_invalid OH_FS "ocfs2 $rdbms_fs_type" "$str_usage"

if [[ $OH_FS != $rdbms_fs_type && $max_nodes -eq 1 ]]
then
	error  "ORACLE_HOME on $OH_FS only for RAC."
	LN
	exit 1
fi

typeset -r	cfg_path=$cfg_path_prefix/$db

function validate_config
{
	exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc 2>&1"
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

	echo "${db_type}:${server_name}:${server_ip}:${server_vip}:${rac_network}:${server_private_ip}:${luns_hosted_by}:${OH_FS}" > $cfg_path/node${num_node}
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

#	Les n° de disques n'ont plus de sens, ils sont conservés car ils permettent
#	de déterminer le nombre de disques nécessaire.
function normalyse_asm_disks
{
	typeset -i i_lun=1

	if [ $db_type == rac ]
	then
		echo "CRS:6:1:3" > $cfg_path/disks
		i_lun=4
	fi

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

	typeset		buffer="DATA:${size_lun_gb}:$i_lun:"
	typeset	-i	last_lun=i_lun+max_luns-1
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks

	buffer="FRA:${size_lun_gb}:$i_lun:"
	last_lun=i_lun+max_luns-1
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks
}

function normalyse_fs_disks
{
	echo "FS:$size_dg_gb:1:1" > $cfg_path/disks
}

validate_config

line_separator
if [ -d $cfg_path ]
then
	confirm_or_exit "$cfg_path exists, remove :"
	exec_cmd rm -rf $cfg_path
fi
exec_cmd mkdir $cfg_path
LN

typeset -i ip_range=1
[ $max_nodes -gt 1 ] && ip_range=max_nodes*2+3	# 2 IP / nodes, 3 SCAN IP
[ $ip_node -eq -1 ] && ip_node=$(ssh $dns_conn "~/plescripts/dns/get_free_ip_node.sh -range=$ip_range")

for i in $(seq $max_nodes)
do
	normalyze_node $i
done

[ $db_type == rac ] && normalyze_scan

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

if [ $usefs == no ]
then
	normalyse_asm_disks
else
	normalyse_fs_disks
fi

~/plescripts/shell/show_info_server -db=$db

info "Run : ./create_database_servers.sh -db=$db"
