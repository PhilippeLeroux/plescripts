#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/san/targetclilib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage="Usage : $ME -name=<str> -user=<str> -password=<str>"

typeset name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-name=*)
			name=${1##*=}
			shift
			;;

		-user=*)
			user=${1##*=}
			shift
			;;

		-password=*)
			password=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef name	"$str_usage"

info "Create iscsi initiator :"
create_iscsi_initiator $name $san_ip_priv $user $password
