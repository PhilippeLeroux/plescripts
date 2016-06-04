#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
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

exit_if_param_undef db	"$str_usage"

typeset -r cfg_path=~/plescripts/infra/$db
exit_if_dir_not_exists $cfg_path

typeset -ri max_nodes=$(ls -1 $cfg_path/node*|wc -l)

upper_db=$(to_upper $db)

line_separator
info "Mise à jour de /etc/oratab"
for inode in $( seq 1 $max_nodes )
do
	exec_cmd "echo \"${upper_db}$inode:/u01/app/oracle/$oracle_release/dbhome_1:N	#added by bibi\" >> /etc/oratab"
done

