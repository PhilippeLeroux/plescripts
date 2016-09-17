#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	[-sga=$shm_for_db]		(Ex : -sga=512M)
"

info "Running : $ME $*"

typeset sga=$shm_for_db

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-sga=*)
			sga=${1##*=}
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

exit_if_param_undef		sga						"$str_usage"

if [ $hack_asm_memory == 0 ]
then
	error "hack_asm_memory not defined."
	exit 1
fi

if [ $sga == 0 ]
then
	if [ $shm_for_db == 0 ]
	then
		error "shm_for_db not defined."
		exit
	fi

	error "sga=0 invalid."
	exit 1
fi

typeset -ri asm_mb=$(to_mb $hack_asm_memory)
typeset -ri sga_mb=$(to_mb $sga)

typeset -ri shm_size=asm_mb+sga_mb
info "New shm size = ${shm_size}M"
exec_cmd "sed -i \"/^.*\/dev\/shm.*/d\" /etc/fstab"
exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults,size=${shm_size}M 0 0\" >> /etc/fstab"
LN

info "Before :"
exec_cmd "df -m /dev/shm"
LN

exec_cmd "mount -o remount /dev/shm"
LN

info "Now :"
exec_cmd "df -m /dev/shm"
LN
