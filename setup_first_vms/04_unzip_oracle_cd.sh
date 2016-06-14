#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

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

if [ ! -d ~/shared/oracle-db ]
then
	error "Le répertoire '~/shared/oracle-db' n'existe pas."
	info "'~/shared/oracle-db doit contenir tous les zip permettant d'installer Oracle & le grid"
	exit 1
fi

[ -d ~/oracle_install ] && exec_cmd mkdir ~/oracle_install

for zip in ~/shared/oracle-db/*.zip
do
	exec_cmd "unzip $zip -d ~/oracle_install/"
done
