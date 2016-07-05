#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME 
Doit être exécuté sur le serveur d'infrastructure."

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

[ -d ~/$oracle_install ] && exec_cmd mkdir -p ~/$oracle_install

for zip in ~/zips/*.zip
do
	exec_cmd "unzip $zip -d ~/$oracle_install/"
done
