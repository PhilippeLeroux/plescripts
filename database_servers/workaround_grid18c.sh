#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME
Lors de la création d'une base avec DBCA on obtient le message d'erreur
[FATAL] PRCR-1006 : Failed to add resource ora.test18c.db for test18c
PRCR-1071 : Failed to register or update resource ora.test18c.db
CRS-2566: User 'oracle' does not have sufficient permissions to operate on resource 'ora.driver.afd', which is part of the dependency specification."

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

#ple_enable_log -params $PARAMS

must_be_user grid

info "Workaround bug 18c :"
info "  Change group asmadmin to oinstall."
LN

exec_cmd "crsctl stat res ora.driver.afd -p | grep ACL=owner"
LN

exec_cmd "crsctl modify resource ora.driver.afd -attr \"ACL='owner:grid:rwx,pgrp:oinstall:r-x,other::r--'\" -init"
LN

exec_cmd "crsctl stat res ora.driver.afd -p | grep ACL=owner"
LN
