#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage : $ME"

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

must_be_user oracle

exit_if_file_not_exists $HOME/profile.oracle

typeset -r	orcl_version=$(read_orcl_version)

# Nécessaire pour oracle_password
if [ "$orcl_version" != "$oracle_release" ]
then
	warning "Bad Oracle Release"
	exec_cmd ~/plescripts/update_local_cfg.sh ORACLE_RELEASE="$orcl_version"

	info "Rerun with local config updated."
	exec_cmd $ME $PARAMS
	LN
	exit 0
fi

#	Code dupliqué et **adapté** du script : oracle_preinstall/01_create_oracle_users.sh
#	L'adaptation est l'ajout de ~/plescripts/oracle_preinstall.
info "Copy and update profile for oracle."
exec_cmd "sed \"s/RELEASE_ORACLE/${orcl_version}/g\"	\
			~/plescripts/oracle_preinstall/template_profile.oracle |					\
			sed \"s/ORA_NLSZZ/ORA_NLS${orcl_version%%.*}/g\" > /home/oracle/profile.oracle"
LN

info "Update sys password for profile.oracle"
exec_cmd "sed -i \"s/ORACLE_PASSWORD/${oracle_password}/g\"	\
											/home/oracle/profile.oracle"
LN
