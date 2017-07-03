#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

A utiliser quand le grid n'est pas installer.

Si le grid est installer, il faut le stopper sinon AFD empêchera toutes actions."

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

must_be_user root

typeset		list_disks
typeset	-i	nr_disk=0
typeset -i	nr_disk_skipped=0

export ORACLE_HOME=$GRID_HOME
export ORACLE_BASE=/tmp
while read oracle_label dev rem
do
	[ $dev == Y ] && dev=$rem || true
	info "clear $oracle_label on $dev"
	clear_device "$dev"
done<<<"$($ORACLE_HOME/bin/asmcmd afd_lslbl '/dev/sd*' | grep -E "^S")"
