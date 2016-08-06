#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Met à jour les adresses MAC de toutes les interfaces.
Utile quand on s'amuse avec les cartes."

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

typeset -r if_path=$(get_if_path)

ifconfig -s |\
while read if_name rem
do
	[ $if_name = "Iface" ] || [ $if_name = "lo" ] && continue

	if_hwaddr=$(get_if_hwaddr $if_name)
	info "$if_name hwaddr : $if_hwaddr"
	if_file=$if_path/ifcfg-$if_name
	if [ -f $if_file ]
	then
		update_value HWADDR $if_hwaddr $if_file
	else
		error "$if_file $KO"
	fi
	LN
done
