#!/bin/bash

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-emul]
	Mise à jour de l'OS, tient compte des bases.
"

info "$ME $@"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

test_if_cmd_exists olsnodes
if [ $? -ne 0 ]
then
	error "Ne fonctionne qu'avec le GI d'installé."
	exit 1
fi

typeset	-r	cur_hostname=$(hostname -s)

exec_cmd -ci "yum check-update >/dev/null 2>&1"
check_update=$?
if [ $check_update -eq 0 ]
then
	info "Par de mise à jour."
	exit 0
fi

if [ $check_update -ne 100 ]
then
	error "Erreur lors du check..."
	exit 1
fi

typeset		node_list=$(olsnodes | xargs)
typeset	-ri	count_nodes=$(wc -w<<<"$node_list")

[ $count_nodes -eq 0 ] && node_list=$cur_hostname

info "Nombre de serveur à mettre à jour : $count_nodes"
info "    $node_list"

line_separator
if [ $count_nodes -gt 1 ]
then	#	C'est un RAC
	exec_cmd "crsctl stop cluster -all"
	exec_cmd "crsctl stop crs"
	LN

	for node_name in $node_list
	do
		if [ $node_name != $cur_hostname ]
		then
			exec_cmd "ssh $node_name \". ./.bash_profile; crsctl stop crs\""
			LN
		fi
	done
else
	exec_cmd "crsctl stop has"
	LN
fi

line_separator
for node_name in $node_list
do
	if [ $node_name != $cur_hostname ]
	then
		exec_cmd "ssh -t $node_name \"yum -y update\""
		[ $? -eq 0 ] && exec_cmd -c "ssh $node_name \"systemctl reboot\""
		LN
	fi
done

line_separator
exec_cmd "yum -y update"
[ $? -eq 0 ] && exec_cmd -c "systemctl reboot" || false
