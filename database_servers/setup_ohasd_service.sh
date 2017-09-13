#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage : $ME

Les disques sont exposés via iSCSI, oracle-ohasd.service ne possède pas
de dépendances sur iscsi.service.

La dépendance est ajoutée.
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

#ple_enable_log -params $PARAMS

must_be_user root

typeset	-r ohasd_service_file=/etc/systemd/system/oracle-ohasd.service

info "Add iSCSI dependency to oracle-ohasd"
LN

exit_if_file_not_exists $ohasd_service_file

if grep -qE iscsi.service $ohasd_service_file
then
	warning "iscsi.service already configured ??"
	LN
	exit 0
fi

exec_cmd "sed -i \"s/^After=\(.*\)/After=\1 iscsi.service/\" $ohasd_service_file"
LN

exec_cmd "sed -i '/^After=/a Wants=iscsi.service' $ohasd_service_file"
LN

exec_cmd "systemctl daemon-reload"
LN
