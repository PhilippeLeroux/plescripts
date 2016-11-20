#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

line_separator
exec_cmd yum -y install	iscsi-initiator-utils	\
						git						\
						$oracle_rdbms_rpm		\
						iotop					\
						~/plescripts/rpm/rlwrap-0.42-1.el7.x86_64.rpm
LN
