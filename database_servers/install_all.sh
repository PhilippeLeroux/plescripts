#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage :
$ME
	-db=name
	[-edition=SE2] default is EE.
"

typeset		db=undef
typeset		edition=EE

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-edition=*)
			edition=$(to_upper ${1##*=})
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
			LN
			exit 1
			;;
	esac
done

#ple_enable_log -params $PARAMS

exit_if_param_undef db	"$str_usage"
cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

line_separator
if [[ $max_nodes -eq 1 ]]
then
	exec_cmd "~/plescripts/database_servers/clone_master.sh -db=$db"
else
	exec_cmd "~/plescripts/database_servers/create_database_servers.sh -db=$db"
fi
LN

timing 20

cfg_load_node_info $db 1

# 12cR2 et 18c même script, pour le moment.
[[ $cfg_orarel == 12.1* ]] && O_VER=12cR1 || O_VER=12cR2

case $cfg_db_type in
	std)
		line_separator
		if [ $cfg_dataguard == yes ]
		then
			exec_cmd "~/plescripts/database_servers/install_grid${O_VER}.sh	\
															-db=$db -dg_node=1"

			timing 20
			LN

			exec_cmd "~/plescripts/database_servers/install_grid${O_VER}.sh	\
															-db=$db -dg_node=2"
		else
			exec_cmd "~/plescripts/database_servers/install_grid${O_VER}.sh -db=$db"
		fi
		timing 20
		LN
		;;
	rac)
		# ======================================================================
		# Note : utilisation de fake_exec_cmd car erreurs ssh avec exec_cmd lors
		# de l'exécution des scripts root du Grid Infra ou d'Oracle pour les RAC.
		# ======================================================================
		line_separator
		fake_exec_cmd "~/plescripts/database_servers/install_grid${O_VER}.sh	\
																	-db=$db"	\
			&& ~/plescripts/database_servers/install_grid${O_VER}.sh -db=$db
		timing 20
		LN
		;;
	fs)
		: # nothing todo
		;;
esac

line_separator
case $cfg_db_type in
	std|fs)
		if [ $cfg_dataguard == yes ]
		then
			exec_cmd "~/plescripts/database_servers/install_oracle.sh	\
															-db=$db -dg_node=1"

			timing 20
			LN

			exec_cmd "~/plescripts/database_servers/install_oracle.sh	\
															-db=$db -dg_node=2"
		else
			exec_cmd "~/plescripts/database_servers/install_oracle.sh	\
													-db=$db -edition=$edition"
		fi
		;;
	rac)
		# ======================================================================
		# Note : utilisation de fake_exec_cmd car erreurs ssh avec exec_cmd lors
		# de l'exécution des scripts root du Grid Infra ou d'Oracle pour les RAC.
		# ======================================================================
		fake_exec_cmd "~/plescripts/database_servers/install_oracle.sh		\
												-db=$db -edition=$edition"	\
			&& ~/plescripts/database_servers/install_oracle.sh				\
												-db=$db -edition=$edition
		;;
esac
