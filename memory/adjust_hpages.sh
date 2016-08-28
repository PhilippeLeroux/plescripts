#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -nr_hugepages=#"

[ $UID -ne 0 ] && error "UID must be 0 !" && exit 1

typeset	-i nr_hugepages=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-nr_hugepages=*)
			nr_hugepages=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef nr_hugepages "$str_usage"

info "Memory configuration before adjustment :"
exec_cmd "free -m"
exec_cmd "df -m /dev/shm"
LN

info "Update hugepages configuration :"
update_value vm.nr_hugepages $nr_hugepages $sysctl_file
exec_cmd "sysctl -w vm.nr_hugepages=$nr_hugepages"
exec_cmd "sysctl vm.nr_hugepages"
LN

info "Memory configuration after adjustment :"
exec_cmd "free -m"
exec_cmd "df -m /dev/shm"
LN

info "RAC update other nodes yourself."
LN

if [ $(sysctl -n vm.nr_hugepages) -ne $nr_hugepages ]
then
	warning "Reboot OS : systemctl reboot"
	LN
	exit 1
else
	exit 0
fi
