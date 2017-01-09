#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

line_separator
info "Install oracleasm packages :"
BL=$LANG; LANG=C
exec_cmd yum -y -q install	cvuqdisk-1.0.9-1.rpm		\
							kmod-oracleasm.x86_64		\
							oracleasm-support.x86_64	\
							oracleasmlib-2.0.12-1.el7.x86_64.rpm
LANG=$BL
LN

exec_cmd "~/plescripts/oracle_preinstall/configure_oracleasm.sh"
