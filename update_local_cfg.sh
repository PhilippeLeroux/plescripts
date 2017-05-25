#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

add_usage "-var=name"		"Variable name to update."
add_usage "-value=value"	"New value or remove."
typeset -r parameters_usage="$(print_usage)"
reset_usage

add_usage "ORACLE_RELEASE=${ORACLE_RELEASE:-$oracle_release}"	"*12.1.0.2*|12.2.0.1"

add_usage new_line
add_usage "ORCL_YUM_REPOSITORY_RELEASE=${ORCL_YUM_REPOSITORY_RELEASE:-$orcl_yum_repository_release}"	"*R3*|R4 Oracle Linux 7 repository"
add_usage "OL7_KERNEL_VERSION=${OL7_KERNEL_VERSION:-$ol7_kernel_version}"								"latest or kernel version, only for BDD servers"

add_usage new_line
case "$ORACLE_RELEASE" in
	12.1*)
		add_usage "VM_MEMORY_MB_FOR_SINGLE_DB_121=${VM_MEMORY_MB_FOR_SINGLE_DB_121:-$vm_memory_mb_for_single_db}"	"VM memory for SINGLE DB 12.1"
		add_usage "VM_NR_CPUS_FOR_SINGLE_DB_121=${VM_NR_CPUS_FOR_SINGLE_DB_121:-$vm_nr_cpus_for_single_db}"			"VM #cpu for SINGLE DB 12.1"
		add_usage new_line
		add_usage "VM_MEMORY_MB_FOR_RAC_DB_121=${VM_MEMORY_MB_FOR_RAC_DB_121:-$vm_memory_mb_for_rac_db}"			"VM memory for RAC DB 12.1"
		add_usage "VM_NR_CPUS_FOR_RAC_DB_121=${VM_NR_CPUS_FOR_RAC_DB_121:-$vm_nr_cpus_for_rac_db}"					"VM #cpu for RAC DB 12.1"
		;;
	12.2*)
		add_usage "VM_MEMORY_MB_FOR_SINGLE_DB_122=${VM_MEMORY_MB_FOR_SINGLE_DB_122:-$vm_memory_mb_for_single_db}"	"VM memory for SINGLE DB 12.2"
		add_usage "VM_NR_CPUS_FOR_SINGLE_DB_122=${VM_NR_CPUS_FOR_SINGLE_DB_122:-$vm_nr_cpus_for_single_db}"			"VM #cpu for SINGLE DB 12.2"
		add_usage new_line
		add_usage "VM_MEMORY_MB_FOR_RAC_DB_122=${VM_MEMORY_MB_FOR_RAC_DB_122:-$vm_memory_mb_for_rac_db}"			"VM memory for RAC DB 12.2"
		add_usage "VM_NR_CPUS_FOR_RAC_DB_122=${VM_NR_CPUS_FOR_RAC_DB_122:-$vm_nr_cpus_for_rac_db_122}"				"VM #cpu for RAC DB 12.2"
		;;
esac

add_usage new_line
add_usage "VM_PATH=${VM_PATH:-$vm_path}" "Where to create VM"
typeset -r vm_params="$(print_usage)"
reset_usage

add_usage "IOSTAT_ON=${IOSTAT_ON:-$iostat_on}" "*BDD*|ALL for script iostat_on_bdd_disks.sh"
typeset -r miscs_params="$(print_usage)"
reset_usage

add_usage "DISKS_HOSTED_BY=${DISKS_HOSTED_BY:-$disks_hosted_by}"	"vbox|*san*"
add_usage "SAN_DISK=${SAN_DISK:-$san_disk}"		"device path for SAN disk|*vdi*"
add_usage "SAN_DISK_SIZE_G=${SAN_DISK_SIZE_G:-$san_disk_size_g}" "Size SAN disk if SAN_DISK=vdi"
typeset -r installation="$(print_usage)"
reset_usage

add_usage "INSTALL_GUESTADDITIONS=${INSTALL_GUESTADDITIONS:-$install_guestadditions}" "yes|*no*"
add_usage "TIMEKEEPING=${TIMEKEEPING:-$timekeeping}" "*ntp_with_kvmclock*|ntp_without_kvmclock"
typeset -r internals="$(print_usage)"

typeset -r str_usage=\
"Usage :
$ME
$parameters_usage

Used to create a new VM for database :
$vm_params

Miscs parameters :
$miscs_params

Used only to create $infra_hostname and $master_hostname :
$installation

Internals :
$internals
"

typeset	var=undef
typeset value=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-var=*)
			var=$(to_upper ${1##*=})
			shift
			;;

		-value=*)
			value=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 0
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

script_banner $ME $*

exit_if_param_undef var		"$str_usage"
exit_if_param_undef value	"$str_usage"

case $var in
	ORACLE_RELEASE) ;;

	ORCL_YUM_REPOSITORY_RELEASE) ;;
	OL7_KERNEL_VERSION) ;;

	VM_MEMORY_MB_FOR_SINGLE_DB_121) ;;
	VM_MEMORY_MB_FOR_RAC_DB_121) ;;
	VM_NR_CPUS_FOR_SINGLE_DB_121) ;;
	VM_NR_CPUS_FOR_RAC_DB_121) ;;

	VM_MEMORY_MB_FOR_SINGLE_DB_122) ;;
	VM_MEMORY_MB_FOR_RAC_DB_122) ;;
	VM_NR_CPUS_FOR_SINGLE_DB_122) ;;
	VM_NR_CPUS_FOR_RAC_DB_122) ;;

	VM_PATH) ;;

	INSTALL_GUESTADDITIONS) ;;

	DISKS_HOSTED_BY) ;;
	SAN_DISK) ;;
	SAN_DISK_SIZE_G) ;;

	TIMEKEEPING) ;;

	IOSTAT_ON) ;;

	*)
		error "Variable '$var' unknow"
		LN
		info "$str_usage"
		LN
		exit 1
esac

typeset -r local_cfg=~/plescripts/local.cfg

[ ! -f $local_cfg ] && touch $local_cfg || true

if [ $var == VM_PATH ]
then
	# Remplace ~ par HOME
	value="${value/\~/$HOME}"
	if [ ! -d "$value" ]
	then
		error "Directory '$value' not exists"
		LN
		exit 1
	fi
	# L'affectation doit se faire avec des 2x quotes pour les espaces & co.
	value="\\\"$value\\\""
fi

if [ "$value" == remove ]
then
	info "Remove variable $var"
	remove_value $var $local_cfg
	LN
else
	info "Update $var = $value"
	update_value $var "$value" "$local_cfg"
	LN
fi
