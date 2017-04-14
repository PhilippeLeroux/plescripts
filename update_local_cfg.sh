#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

add_usage "-var=name"		"Variable name to update."
add_usage "-value=value"	"New value or remove."

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

List :
	ORACLE_RELEASE

	ORCL_YUM_REPOSITORY_RELEASE

	VM_MEMORY_MB_FOR_SINGLE_DB_121
	VM_MEMORY_MB_FOR_RAC_DB_121
	VM_NR_CPUS_FOR_SINGLE_DB_121
	VM_NR_CPUS_FOR_RAC_DB_121

	VM_MEMORY_MB_FOR_SINGLE_DB_122
	VM_MEMORY_MB_FOR_RAC_DB_122
	VM_NR_CPUS_FOR_SINGLE_DB_122
	VM_NR_CPUS_FOR_RAC_DB_122

	VM_PATH

	INSTALL_GUESTADDITIONS

	DISKS_HOSTED_BY
	SAN_DISK
	SAN_DISK_SIZE_G

	TIMEKEEPING

	IOSTAT_ON
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

script_banner $ME $*

exit_if_param_undef var		"$str_usage"
exit_if_param_undef value	"$str_usage"

case $var in
	ORACLE_RELEASE) ;;

	ORCL_YUM_REPOSITORY_RELEASE) ;;

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

if [ "$value" == remove ]
then
	info "Remove variable $var"
	remove_value $var $local_cfg
	LN
else
	info "Update $var = $value"
	update_value $var $value $local_cfg
	LN
fi
