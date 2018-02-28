#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage :
$ME
	-kernel=[UEK|RHEL]
	[-force] with UEK no test current IO scheduler.

	Must be executed only on $infra_hostname

	* UEK  : enable IO scheduler $infra_io_scheduler
	* RHEL : remove IO scheduler $infra_io_scheduler if exists.
"

typeset		kernel=undef
typeset		force=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-kernel=*)
			kernel=${1##*=}
			shift
			;;

		-force)
			force=yes
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

exit_if_param_invalid kernel "UEK RHEL"	"$str_usage"

must_be_user root
must_be_executed_on_server $infra_hostname

if [ $kernel == UEK ]
then
	io_scheduler=$(sed "s/.*\[\(.*\)\].*/\1/" /sys/block/sda/queue/scheduler)
	if [[ $force == yes || $infra_io_scheduler != $io_scheduler ]]
	then
		info "Enable default IO scheduler : $infra_io_scheduler"
		exec_cmd "$HOME/plescripts/grub2/setup_kernel_boot_options.sh -add='elevator=$infra_io_scheduler'"
		LN
	fi
elif grep -q "elevator=" /etc/grub2.cfg
then
	info "Remove elevator."
	exec_cmd "$HOME/plescripts/grub2/setup_kernel_boot_options.sh -remove='elevator=$infra_io_scheduler'"
	LN
fi
