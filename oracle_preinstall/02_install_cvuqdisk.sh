#!/bin/bash
# vim: ts=4:sw=4:ft=sh
# ft=sh car la colorisation ne fonctionne pas si le nom du script commence par
# un n°

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

For iSCSI
"

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

if [ "${oracle_release%.*.*}" == "12.1" ]
then
	info "Install cvuqdisk-1.0.9-1.rpm"
	exec_cmd "LANG=C yum -y -q install /mnt/oracle_install/grid/rpm/cvuqdisk-1.0.9-1.rpm"
	LN
else
	info "Extract cvuqdisk-1.0.10-1.rpm from zip archive to /tmp"
	exec_cmd "unzip	-j	\"/mnt/oracle_install/grid/linuxx64_12201_grid_home.zip\"	\
							\"cv/rpm/cvuqdisk-1.0.10-1.rpm\"						\
					-d \"/tmp\""
	LN

	info "Install cvuqdisk-1.0.10-1.rpm"
	exec_cmd "LANG=C yum -y -q install /tmp/cvuqdisk-1.0.10-1.rpm"
	LN

	info "Remove /tmp/cvuqdisk-1.0.10-1.rpm"
	exec_cmd "rm -f /tmp/cvuqdisk-1.0.10-1.rpm"
	LN
fi
