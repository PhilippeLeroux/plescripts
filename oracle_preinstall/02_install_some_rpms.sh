#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

line_separator
BL=$LANG; LANG=C
exec_cmd yum -y -q install	$oracle_rdbms_rpm		\
							iotop					\
							~/plescripts/rpm/rlwrap-0.42-1.el7.x86_64.rpm
LANG=$BL
LN
