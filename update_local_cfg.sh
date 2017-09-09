#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

add_usage "variable=value"
add_usage "Ex to update variable VM_PATH with value ~/VBoxVMs :"
add_usage "   $ ./update_local_cfg.sh VM_PATH=~/VBoxVMs"
typeset -r parameters_usage="$(print_usage)"
reset_usage

ORACLE_RELEASE=${ORACLE_RELEASE:-$oracle_release}
add_usage "ORACLE_RELEASE=${ORACLE_RELEASE}"	"*12.1.0.2*|12.2.0.1"

add_usage new_line
add_usage "OL7_KERNEL_VERSION=${OL7_KERNEL_VERSION:-$ol7_kernel_version}"								"latest or kernel version, only for BDD servers"

add_usage new_line
case "$ORACLE_RELEASE" in
	12.1*)
		add_usage "VM_MEMORY_MB_FOR_SINGLE_DB_121=${VM_MEMORY_MB_FOR_SINGLE_DB_121:-$vm_memory_mb_for_single_db}"	"VM memory for SINGLE DB 12.1"
		add_usage "VM_NR_CPUS_FOR_SINGLE_DB_121=${VM_NR_CPUS_FOR_SINGLE_DB_121:-$vm_nr_cpus_for_single_db}"			"VM #cpu for SINGLE DB 12.1"
		add_usage new_line
		add_usage "VM_MEMORY_MB_FOR_RAC_DB_121=${VM_MEMORY_MB_FOR_RAC_DB_121:-$vm_memory_mb_for_rac_db}"			"VM memory for RAC DB 12.1"
		add_usage "VM_NR_CPUS_FOR_RAC_DB_121=${VM_NR_CPUS_FOR_RAC_DB_121:-$vm_nr_cpus_for_rac_db}"					"VM #cpu for RAC DB 12.1"
		add_usage new_line
		add_usage "ORCL_YUM_REPOSITORY_RELEASE121=${ORCL_YUM_REPOSITORY_RELEASE121:-$orcl_yum_repository_release}"	"DVD_R2|*DVD_R3*|latest|R3|R4 Oracle Linux 7 repository"
		;;
	12.2*)
		add_usage "VM_MEMORY_MB_FOR_SINGLE_DB_122=${VM_MEMORY_MB_FOR_SINGLE_DB_122:-$vm_memory_mb_for_single_db}"	"VM memory for SINGLE DB 12.2"
		add_usage "VM_NR_CPUS_FOR_SINGLE_DB_122=${VM_NR_CPUS_FOR_SINGLE_DB_122:-$vm_nr_cpus_for_single_db}"			"VM #cpu for SINGLE DB 12.2"
		add_usage new_line
		add_usage "VM_MEMORY_MB_FOR_RAC_DB_122=${VM_MEMORY_MB_FOR_RAC_DB_122:-$vm_memory_mb_for_rac_db}"			"VM memory for RAC DB 12.2"
		add_usage "VM_NR_CPUS_FOR_RAC_DB_122=${VM_NR_CPUS_FOR_RAC_DB_122:-$vm_nr_cpus_for_rac_db_122}"				"VM #cpu for RAC DB 12.2"
		add_usage new_line
		add_usage "ORCL_YUM_REPOSITORY_RELEASE122=${ORCL_YUM_REPOSITORY_RELEASE122:-$orcl_yum_repository_release}"	"DVD_R2|*DVD_R3*|latest|R3|R4 Oracle Linux 7 repository"
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

# $1 variable name
# return 1 if valid, else return 0
function variable_is_valid
{
	case $var in
		ORACLE_RELEASE) return 0 ;;

		ORCL_YUM_REPOSITORY_RELEASE121) return 0 ;;
		ORCL_YUM_REPOSITORY_RELEASE122) return 0 ;;
		OL7_KERNEL_VERSION) return 0 ;;

		VM_MEMORY_MB_FOR_SINGLE_DB_121) return 0 ;;
		VM_MEMORY_MB_FOR_RAC_DB_121) return 0 ;;
		VM_NR_CPUS_FOR_SINGLE_DB_121) return 0 ;;
		VM_NR_CPUS_FOR_RAC_DB_121) return 0 ;;

		VM_MEMORY_MB_FOR_SINGLE_DB_122) return 0 ;;
		VM_MEMORY_MB_FOR_RAC_DB_122) return 0 ;;
		VM_NR_CPUS_FOR_SINGLE_DB_122) return 0 ;;
		VM_NR_CPUS_FOR_RAC_DB_122) return 0 ;;

		VM_PATH) return 0 ;;

		INSTALL_GUESTADDITIONS) return 0 ;;

		DISKS_HOSTED_BY) return 0 ;;
		SAN_DISK) return 0 ;;
		SAN_DISK_SIZE_G) return 0 ;;

		TIMEKEEPING) return 0 ;;

		IOSTAT_ON) return 0 ;;

		*)
			return 1 ;;
	esac
}

typeset	var=undef
typeset value=undef

if [ $# -eq 0 ]
then
	info "$str_usage"
	LN
	exit 1
fi

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
			exit 0
			;;

		*)
			# Attend variable=value
			IFS=\= read var value<<<"$1"
			var=$(to_upper $var)
			if ! variable_is_valid $var
			then
				error "Variable '$var' invalid."
				LN
				info "$str_usage"
				LN
				exit 1
			fi
			shift

			;;
	esac
done


typeset -r local_cfg=~/plescripts/local.cfg

[ ! -f $local_cfg ] && touch $local_cfg || true

if [ "$value" == remove ]
then
	info "Remove variable $var"
	remove_value $var $local_cfg
	LN
else

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

	info "Update $var = $value"
	update_value $var "$value" "$local_cfg"
	LN
fi
