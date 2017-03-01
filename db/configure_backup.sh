#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-with_standby]"

script_banner $ME $*

typeset	with_standby=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-with_standby)
			with_standby=yes
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

exit_if_ORACLE_SID_not_defined

exec_cmd "cd ~/plescripts/db"
LN

# Si le block change tracking est déjà activé le script n'est pas
# interrompu.
exec_cmd -c "rman target sys/$oracle_password	\
									@rman/enable_block_change_tracking.sql"
LN

exec_cmd "rman target sys/$oracle_password	\
									@rman/set_config.rman"

if [ $with_standby == yes ]
then
	exec_cmd "rman target sys/$oracle_password \
									@rman/ajust_config_for_dataguard.rman"
	LN
fi

exec_cmd "cd -"
LN

info "Configuration done."
info "Backup script : rman/image_copy_level1.rman"
LN
