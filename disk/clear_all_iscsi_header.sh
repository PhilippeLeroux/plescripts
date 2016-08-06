#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/disklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=NOP

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-doit]
	Efface l'en-tête de tous les disques iscsi.

	Par défaut affiche se qu'il va faire.
	Pour l'exécution réel utiliser -doit
"

while [ $# -ne 0 ]
do
	case $1 in
		-doit)
			EXEC_CMD_ACTION=EXEC
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

get_iscsi_disks |\
while read disk_name disk_num
do
	clear_device $disk_name
	LN
done

[ $EXEC_CMD_ACTION = NOP ] && info "$str_usage"
