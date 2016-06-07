#!/bin/sh

#	ts=4	sw=4

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

typeset -r service_file=/usr/lib/systemd/system/oracledb.service

if [ -f $service_file ]
then
	info "Le service oracledb existe."
	exec_cmd "systemctl status oracledb.service -l"
	exit 0
fi

info "Create systemd service for Oracle Database"

cat <<EOS > $service_file
[Unit]
Description=Start all Oracle database
Wants=iscsi.service
After=iscsi.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/su - oracle -c "~/plescripts/db/fsdb.sh -start"
ExecStop=/usr/bin/su - oracle -c "~/plescripts/db/fsdb.sh -stop"

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

info "Enable service"
exec_cmd "systemctl enable oracledb.service"
LN

info "Start service"
exec_cmd -c "systemctl start oracledb.service"

info "Status"
exec_cmd "systemctl status oracledb.service -l"
LN
