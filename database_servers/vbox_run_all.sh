#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME\
	-db=id
	[-standby=id]  Permet de créer une standby.
	[-max_nodes=#] Pour un RAC préciser le nombre de nœuds.
	[others]       Transmis à create_db.sh
"

info "Running : $ME $*"

typeset db=undef
typeset standby=undef
typeset max_nodes=1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-standby=*)
			standby="${1##*=}"
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-max_nodes=*)
			max_nodes=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			break
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

script_start

typeset	vmGroup
[ $standby != undef ] && vmGroup="/DG $(initcap $db) et $(initcap $standby)"

function configure_server
{
	typeset -r db=$1

	exec_cmd ./define_new_server.sh -db=$db -max_nodes=$max_nodes -luns_hosted_by=vbox
	LN

	for inode in $( seq $max_nodes )
	do
		exec_cmd ./clone_master.sh -db=$db -node=$inode -vmGroup=\"$vmGroup\"
		LN
	done

	exec_cmd ./install_grid.sh -db=$db
	LN

	exec_cmd ./install_oracle.sh -db=$db
	LN
}

configure_server $db

exec_cmd "ssh -t -t oracle@srv${db}01 \". .profile; db/create_db.sh -y -db=$db $@\""
LN

if [ $standby != undef ]
then
	configure_server $standby

	exec_cmd "~/plescripts/db/stby/00_setup_equivalence.sh					\
				-user1=oracle -server1=srv${db}01 -server2=srv${standby}01"
	LN

	exec_cmd "ssh -t -t oracle@srv${db}01 \". .profile;					\
				db/stby/create_dataguard.sh								\
					-standby=$standby -standby_host=srv${standby}01\""
	LN
fi

script_stop $ME
