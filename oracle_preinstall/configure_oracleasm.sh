#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

line_separator
info "Configure oracleasm"
if ! grep -q "oracleasm is deprecated." /etc/init.d/oracleasm
then
	info "    OLD oracleasm version."
	fake_exec_cmd "/etc/init.d/oracleasm configure <<< grid asmadmin y y"
	/etc/init.d/oracleasm configure <<-EOS
	grid
	asmadmin
	y
	y
	EOS
	LN
else
	info "    NEW oracleasm version."
	fake_exec_cmd "oracleasm configure -i<<<\"grid asmadmin y y\""
	oracleasm configure -i<<-EOS
	grid
	asmadmin
	y
	y
	EOS
	LN
fi

exec_cmd oracleasm configure
#oracleasm init n'est utile que si une désinstallation a été faite.
exec_cmd oracleasm init
exec_cmd oracleasm-discover
exec_cmd systemctl enable oracleasm.service
LN

line_separator
typeset -r service_file=/usr/lib/systemd/system/oracleasm.service
info "Backup $service_file"
exec_cmd -c cp $service_file ${service_file}.$(date +%Y%m%d%H%M)
LN

if ! grep -q "Wants=iscsi.service" $service_file
then
	info "Update file $service_file"
	info "Must be started after iscsi service"
	exec_cmd "sed -i '/Description/a After=iscsi.service' $service_file"
	exec_cmd "sed -i '/Description/a Wants=iscsi.service' $service_file"
	LN
else
	info "[$OK] $service_file"
	LN
fi
