# vim: ts=4:sw=4
#/bin/bash

[ -z plelib_release ] && error "~/plescripts/plelib.sh doit être incluse" && exit 1

#	============================================================================
[ -f /root/pletarget.cfg ] && . /root/pletarget.cfg || true
# Le fichier /root/pletarget.cfg permet de modifier la valeur par défaut de ces
# paramètres :
typeset -r	cache_dynamic_acls=${CACHE_DYNAMIC_ACLS:-0}
typeset -r	demo_mode_write_protect=${DEMO_MODE_WRITE_PROTECT:-0}
typeset -r	generate_node_acls=${GENERATE_NODE_ACLS:-0}
typeset -r	default_cmdsn_depth=${DEFAULT_CMDSN_DEPTH:-8}
typeset -r	backstore_type=${BACKSTORE_TYPE:-block}
#	============================================================================

typeset		working_vg=no_vg_define

#*> set default setting of targetclif
function set_targetcli_default_settings
{
	info "false permet d'avoir des LUNs en lecture seul."
	exec_cmd targetcli / set global auto_add_mapped_luns=false
	LN

	info "Pas de création du portal 0.0.0.0"
	exec_cmd targetcli / set global auto_add_default_portal=false
	LN

	info "Pas de sauvegardes automatique."
	exec_cmd targetcli / set global auto_save_on_exit=false
	LN
}

#*> Reset all config and call set_targetcli_default_settings
function reset
{
	exec_cmd targetcli clearconfig confirm=true
	LN

	set_targetcli_default_settings
}

#*> $1 name of VG to used.
function set_working_vg
{
	working_vg=$1
}

#*> $1 function name
#*> $2 number parameters required for function
#*> $3 number of parameters for function
#*>
#*> exit 1 if $2 -ne $3
function check_params
{
	typeset -r	function_name=$1
	typeset -ri	function_param=$2
	typeset -ri	passed_param=$3

	if [ $function_param -ne $passed_param ]
	then
		error "$function_name wait $function_param parameter(s), only $passed_param"
		exit 1
	fi
}

#*> Create iSCSI initiator.
#*>
#*>	$1	initiator name
#*>	$2	portal
#*>	$3	userid
#*>	$4	password
function create_iscsi_initiator
{
	check_params create_iscsi 4 $#

	typeset -r l_initiator_name=$1
	typeset -r l_portal=$2
	typeset -r l_userid=$3
	typeset -r l_password=$4

	info "$l_initiator_name tpg1 parameters :"
	info "  -cache_dynamic_acls      $cache_dynamic_acls"
	info "  -demo_mode_write_protect $demo_mode_write_protect"
	info "  -generate_node_acls      $generate_node_acls"
	info "  -default_cmdsn_depth     $default_cmdsn_depth"
	LN

	exec_cmd targetcli /iscsi/ create $l_initiator_name
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1 set attribute cache_dynamic_acls=$cache_dynamic_acls
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1 set attribute demo_mode_write_protect=$demo_mode_write_protect
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1 set attribute generate_node_acls=$generate_node_acls
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1 set attribute default_cmdsn_depth=$default_cmdsn_depth
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/portals/ create $l_portal

	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/acls create $l_initiator_name
	#	L'authentification ne marche pas et je ne sais pas pourquoi :(
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/acls/$l_initiator_name set auth mutual_userid=$l_userid
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/acls/$l_initiator_name set auth mutual_password=$l_password
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/acls/$l_initiator_name set auth userid=$l_userid
	exec_cmd targetcli /iscsi/$l_initiator_name/tpg1/acls/$l_initiator_name set auth password=$l_password
}

#*>	delete initiator $1.
function delete_iscsi_initiator
{
	typeset -r l_initiator_name=$1

	exec_cmd targetcli /iscsi/ delete $l_initiator_name
}

#*>	Print to stdout LV name
#*>
#*>	$1 LUN number
#*>	$2 LV prefix
function get_lv_name
{
	printf "lv%s%02d" $2 $1
}

#*>	$1 LUN number
#*>	$2 LV prefix
#*>
#*> Print to stdout disk name.
#*>
#*> Now just call get_lv_name else name is too long.
function get_disk_name
{
	get_lv_name $1 $2
}

#*> Create a LUN to the backstore.
#*>
#*>	$1 LUN number
#*>	$2 LV prefix
function create_backstore
{
	typeset -ri	lun_number=$1
	typeset -r	lv_prefix=$2
	typeset -r	lv_name=$(get_lv_name $lun_number $lv_prefix)
	typeset -r	disk_name=$(get_disk_name $lun_number $lv_prefix)

	typeset -r	test_first="/backstores/$backstore_type/$disk_name"
	targetcli ls $test_first >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		warning "$test_first exist."
	else
		exec_cmd targetcli /backstores/$backstore_type/ create name=${disk_name} dev=/dev/$working_vg/$lv_name
	fi
}

#*> Delete a LUN from the backstore.
#*>
#*>	$1 #LUN
#*>	$2 LV prefix
function delete_backstore
{
	typeset -r lv_name=$(get_lv_name $1 $2)
	typeset -r disk_name=$(get_disk_name $1 $2)

	exec_cmd -cont targetcli /backstores/$backstore_type/ delete ${disk_name}
}

#*>	Create a LUN
#*>
#*>	$1	LUN number
#*>	$2	initiator name
#*>	$3	LV prefix
function create_lun
{
	typeset -r lv_name=$(get_lv_name $1 $3)
	typeset -r disk_name=$(get_disk_name $1 $3)
	typeset -r l_initiator_name=$2

	exec_cmd -c targetcli /iscsi/$l_initiator_name/tpg1/luns/ create /backstores/$backstore_type/${disk_name} $1 true
}

#*>	Delete from the backstore all LUN in range [$1,$2]
#*>
#*>	$1	First LUN number.
#*>	$2	Last LUN number.
function delete_backstore_range
{
	typeset -ri count=$(( $1 + $2 - 1 ))
	for n in $(seq $1 $count)
	do
		delete_backstore $n
	done
}

#*> Create LUN in the backstore
#*>
#*>	$1	First LUN number.
#*>	$2	Last LUN number.
#*>	$3	LV prefix
function create_backstore_range
{
	typeset -ri count=$(( $1 + $2 - 1 ))
	for n in $(seq $1 $count)
	do
		create_backstore $n $3
	done
}

#*> Create LUNs
#*>
#*>	$1	First LUN number.
#*>	$2	Last LUN number.
#*>	$3	l_initiator_name
#*>	$4	LV prefix
function create_lun_range
{
	typeset -r l_initiator_name=$3

	typeset -ri count=$(( $1 + $2 - 1 ))
	for n in $(seq $1 $count)
	do
		create_lun $n $l_initiator_name $4
	done
}
