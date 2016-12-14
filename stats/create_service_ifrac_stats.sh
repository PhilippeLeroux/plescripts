#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME"

[ "$USER" != "root" ] && error "User must be root." && exit 1

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

typeset -r service_name=pleifracstats
typeset -r service_file=/usr/lib/systemd/system/$service_name.service

if [ -f $service_file ]
then
	info "$service_name service exists."
	exec_cmd systemctl stop $service_name
	exec_cmd systemctl disable $service_name
	exec_cmd rm -f $service_file
fi

info "Create systemd service $service_name"

cat <<EOS > $service_file
[Unit]
Description=PLE Interco RAC Statistics
Wants=nfs.target
After=nfs.target

[Service]
Type=simple
ExecStart=/root/plescripts/stats/ifstats.sh -title=$(hostname -s) -ifname=$if_rac_name
ExecStop=/root/plescripts/stats/ifstats.sh -stop -title=$(hostname -s) -ifname=$if_rac_name
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOS

if [ ! -f $service_file ]
then
	error "Cannot create $service_file !"
	exit 1
fi

info "$service_file created."
exec_cmd "cat $service_file"
LN

[ x"$PLE_STATISTICS" == x ] && PLE_STATISTICS=$PLESTATISTICS || true

if grep -q IFRAC <<< "$PLE_STATISTICS"
then
	info "Enable service"
	exec_cmd "systemctl enable $service_name"
	LN

	info "Start service"
	exec_cmd "systemctl start $service_name"
	LN
fi
