#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Ne pas utiliser ce script directement."

script_banner $ME $*

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

exit_if_file_not_exist /mnt/oracle_install/database/runInstaller "$str_usage"

info "deinstall oracle"
fake_exec_cmd /mnt/oracle_install/database/runInstaller -deinstall -home $ORACLE_HOME
if [ $? -eq 0 ]
then
/mnt/oracle_install/database/runInstaller -deinstall -home $ORACLE_HOME<<EOS

y
EOS
fi
LN

exit 0
