#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -server_list=<name1 name2 ...>"

info "Running : $ME $*"

typeset	server_list=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-server_list=*)
			server_list=${1##*=}
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

exit_if_param_undef server_list "$str_usage"

for server in $server_list
do
	info "$server"
	exec_cmd "scp ~/plescripts/yum/public-yum-ol7.repo root@$server:/etc/yum.repos.d"
	exec_cmd "ssh root@$server \"echo 'K2:/repo/ol7/os/x86_64 /mnt/repo/ol7/os/x86_64 nfs ro,noatime,nodiratime,async,comment=systemd.automount 0 0' >> /etc/fstab\""
	exec_cmd "ssh root@$server mkdir -p /mnt/repo/ol7/os/x86_64"
	exec_cmd "ssh root@$server mount /mnt/repo/ol7/os/x86_64"
	LN
done
