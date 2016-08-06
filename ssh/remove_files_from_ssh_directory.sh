#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]
		Purge le répertoire .ssh pour les utilisateurs root, grid et oracle."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

exec_cmd "rm -f /root/.ssh/*"
exec_cmd "rm -f /home/oracle/.ssh/*"
exec_cmd "rm -f /home/grid/.ssh/*"
