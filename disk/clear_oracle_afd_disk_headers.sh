#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME

A utiliser quand le grid n'est pas installer.

Si le grid est installer, il faut le stopper sinon AFD empêchera toutes actions.

Quand le grid est installé il faut faire un asmcmd afd_unlabel XXXXXXXX
"

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

if lsmod | grep -q "afd"
then
	error "AFD driver loaded."
	info "Execute : rmmod oracleafd"
	LN
	exit 1
fi

while read c1 c2 disk_name size_gb ltype type sep asm_name
do
	[ x"$disk_name" == x ] && continue || true

	info "$asm_name"
	clear_device $disk_name
	LN
done<<<"$(~/plescripts/disk/check_disks_type.sh -afdonly|grep oracleasm)"
