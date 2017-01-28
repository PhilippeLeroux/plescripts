#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0

script_banner $ME $*

typeset		db=undef
typeset		standby=undef
typeset		max_nodes=1
typeset	-i	db_size_gb=$default_size_dg_gb
typeset		luns_hosted_by=san

typeset -r	str_usage=\
"Usage : $ME
	-db=name
	[-vbox]          Utiliser VBox pour gérer les LUNs.
	[-db_size_gb=$db_size_gb] Taille de la base.
	[-standby=name]  Permet de créer une standby.
	[-max_nodes=#]   Pour un RAC préciser le nombre de nœuds.
	[others]         Transmis à create_db.sh
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-vbox)
			luns_hosted_by=vbox
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

		-db_size_gb=*)
			db_size_gb=${1##*=}
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

#	$1 db name
#	Create server(s)
#	Install grid
#	Install oracle
function create_database_server
{
	exec_cmd ./define_new_server.sh							\
							-db=$1							\
							-size_dg_gb=$db_size_gb			\
							-max_nodes=$max_nodes			\
							-luns_hosted_by=$luns_hosted_by
	LN

	for inode in $( seq $max_nodes )
	do
		exec_cmd ./clone_master.sh -db=$1 -node=$inode -vmGroup=\"$vmGroup\"
		LN
	done

	exec_cmd ./install_grid.sh -db=$1
	LN

	exec_cmd ./install_oracle.sh -db=$1
	LN
}

#	Create standby server(s)
#	Install grid
#	Install oracle
#	Create dataguard
function create_standby_database_server
{
	create_database_server $standby

	add_dynamic_cmd_param "-user1=oracle"
	add_dynamic_cmd_param "-server1=srv${db}01"
	add_dynamic_cmd_param "-server2=srv${standby}01"
	exec_dynamic_cmd "~/plescripts/ssh/setup_ssh_equivalence.sh"
	LN

	add_dynamic_cmd_param "\". .bash_profile;"
	add_dynamic_cmd_param "~/plescripts/db/stby/create_dataguard.sh"
	add_dynamic_cmd_param "    -standby=$standby"
	add_dynamic_cmd_param "    -standby_host=srv${standby}01\""
	exec_dynamic_cmd "ssh -t -t oracle@srv${db}01"
	LN
}

#	exit 1 if parameters "$@" invalides
function validate_params
{
	exec_cmd -c "~/plescripts/db/create_db.sh -validate_params -y -db=$db $@"
	if [ $? -ne 0 ]
	then
		LN
		error "Invalid parameter !"
		LN
		info "$str_usage"
		LN
		exit 1
	fi
	LN
}

if [ "$db" == "$standby" ]
then
	error "db $db == standby $standby"
	LN
	info "$str_usage"
	LN
	exit 1
fi

validate_params "$@"

create_database_server $db

line_separator
add_dynamic_cmd_param "     \". .bash_profile;"
add_dynamic_cmd_param "     ~/plescripts/db/create_db.sh -y -db=$db $@\""
exec_dynamic_cmd "ssh -t -t oracle@srv${db}01"
LN

[ $standby != undef ] && create_standby_database_server || true

script_stop $ME $db
