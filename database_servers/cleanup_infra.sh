#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="
Usage : $ME
	-db=name
	[-keep_vm]         keep VMs.
	[-keep_cfg_files]  keep configuration files.
"

typeset	db=undef
typeset	delete_vms=yes
typeset	remove_cfg_file=yes

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-keep_vms)
			delete_vms=no
			shift
			;;

		-keep_cfg_files)
			remove_cfg_file=no
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

ple_enable_log

script_banner $ME $*

exit_if_param_undef db	"$str_usage"

cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

typeset -r upper_db=$(to_upper $db)

if [ $delete_vms == yes ]
then
	line_separator
	exec_cmd -c "~/plescripts/shell/delete_vm -db=$db -y"
	LN
fi

if [ -f ~/.ssh/known_hosts ]
then
	line_separator
	for (( inode=1; inode <= max_nodes; ++inode ))
	do
		cfg_load_node_info $db $inode
		remove_from_known_hosts $cfg_server_name
		exec_cmd "ssh -t $dns_conn					\
				plescripts/ssh/remove_from_known_host.sh -host=$cfg_server_name"
		if [[ $max_nodes -gt 1 && $inode -eq 1 ]]
		then	# Supprime les scans.
			remove_from_known_hosts ${db}-scan
		fi
		[ $delete_vms == yes ] && exec_cmd rm -rf \"$vm_path/$cfg_server_name\"
		LN
		info "Clearing arp cache."
		#	Ne pas utiliser arp -d sinon le cache des autres serveurs n'est pas mis
		#	à jour.
		exec_cmd sudo ip -s -s neigh flush all
	done
fi
LN

line_separator
info "Update DNS :"
exec_cmd "ssh -t $dns_conn plescripts/dns/remove_db_from_dns.sh -db=$db"
LN

line_separator
info "Remove keys"
exec_cmd "ssh -t $dns_conn plescripts/dns/clean_up_ssh_authorized_keys.sh"
LN

line_separator
info "Update SAN :"
exec_cmd "ssh -t $san_conn plescripts/san/reset_all_for_db.sh -db=$db"
LN

line_separator
info "Clean up local DNS cache :"
exec_cmd -c sudo systemctl restart nscd.service
LN

if [ $remove_cfg_file == yes ]
then
	line_separator
	info "Remove $cfg_path_prefix/$db"
	exec_cmd -c "rm -rf $cfg_path_prefix/$db"
	LN
fi

info "To flush network :"
info "$ ~/plescripts/virtualbox/restart_vboxdrv.sh"
LN
