#!/bin/ksh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -server=<str>"

info "$ME $@"

typeset server=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-server=*)
			server=${1##*=}
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

exit_if_param_undef server	"$str_usage"

info "Couleur par défaut plus adapté au fond clair."
typeset -r DIR_COLORS=~/plescripts/myconfig/suse_dir_colors
exec_cmd "scp $DIR_COLORS root@$server:.dir_colors"
exec_cmd "scp $DIR_COLORS grid@$server:.dir_colors"
exec_cmd "scp $DIR_COLORS oracle@$server:.dir_colors"

