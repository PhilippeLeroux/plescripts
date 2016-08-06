#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

function configure_oracleasm
{
fake_exec_cmd "/etc/init.d/oracleasm configure grid asmadmin y y"
/etc/init.d/oracleasm configure <<EOS
grid
asmadmin
y
y
EOS
}

line_separator
info "Install oracleasm packages :"
exec_cmd yum -y install cvuqdisk-1.0.9-1.rpm		\
						kmod-oracleasm.x86_64		\
						oracleasm-support.x86_64	\
						oracleasmlib-2.0.12-1.el7.x86_64.rpm
LN

line_separator
info "Configure oracleasm"
configure_oracleasm
exec_cmd oracleasm configure
#oracleasm init n'est utile que si une désinstallation a été faite.
exec_cmd oracleasm init
exec_cmd oracleasm-discover
exec_cmd systemctl enable oracleasm.service
LN

line_separator
typeset -r service_file=/usr/lib/systemd/system/oracleasm.service
info "Backup $service_file"
exec_cmd -c mv $service_file ${service_file}.orignal
LN

info "Update file $service_file"
info "must be started after iscsi service"
cat <<EOS >$service_file
[Unit]
Description=Load oracleasm Modules
Wants=iscsi.service
After=iscsi.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/service  oracleasm start_sysctl
ExecStop=/usr/sbin/service   oracleasm stop_sysctl
ExecReload=/usr/sbin/service oracleasm restart_sysctl

[Install]
WantedBy=multi-user.target
EOS
LN
