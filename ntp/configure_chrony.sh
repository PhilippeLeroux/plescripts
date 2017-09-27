#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME -role=[infra|master]
Configure NTP for infra or master server (use chrony).
"

typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-role=*)
			role=${1##*=}
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

exit_if_param_invalid role "master infra" "$str_usage"

typeset -r chrony_conf=/etc/chrony.conf
exit_if_file_not_exists $chrony_conf

[ $role == master ] && time_server=$infra_hostname || time_server=$master_time_server

typeset	backup=todo

if [ $time_server != internet ]
then
	backup=is_done
	info "Config $chrony_conf"
	exec_cmd "cp $chrony_conf ${chrony_conf}.backup"
	exec_cmd "sed -i '/^server.*iburst$/d' $chrony_conf"
	exec_cmd "sed -i '3i\server $time_server iburst' $chrony_conf"
	LN
fi

if [ $role == infra ]
then
	[ $backup == todo ] && exec_cmd "cp $chrony_conf ${chrony_conf}.backup"

	typeset	-r network=$(right_pad_ip $infra_network)
	exec_cmd "sed -i 's/.*allow .*/allow ${network}\/$if_pub_prefix/g' $chrony_conf"
	LN
fi

info "Enable & start chrony"
exec_cmd "systemctl enable chronyd"
# Si le service est déjà démarré la nouvelle configuration n'est pas prise en
# compte, donc restart
exec_cmd "systemctl restart chronyd"
LN

if [[ $role == infra && "$time_server" != internet ]]
then
	timing 2 "Wait sync to $time_server"
	info -n "Sync with $time_server "
	if ! chronyc sources|grep -q $time_server
	then
		info -f "[$KO]"
		LN
		exit 1
	else
		info -f "[$OK]"
		LN
		exit 0
	fi
fi
