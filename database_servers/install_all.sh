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
$ME -db=name"

typeset	db=undef

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

		-h|-help|help)
			fake_exec_cmd "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			fake_exec_cmd "$str_usage"
			exit 1
			;;
	esac
done

#ple_enable_log -params $PARAMS

exit_if_param_undef db	"$str_usage"
cfg_exists $db

typeset	-ri	max_nodes=$(cfg_max_nodes $db)

# Note : utilisation de fake_exec_cmd car erreurs ssh avec exec_cmd et les scripts
# root du Grid Infra 12cR2
line_separator
if [[ $max_nodes -eq 1 ]]
then
	fake_exec_cmd ./clone_master.sh -db=$db
	./clone_master.sh -db=$db
	[ $? -ne 0 ] && exit 1 || true
else
	fake_exec_cmd ./create_database_servers.sh -db=$db
	./create_database_servers.sh -db=$db
	[ $? -ne 0 ] && exit 1 || true
fi
LN

timing 20

cfg_load_node_info $db 1

[[ $cfg_orarel == 12.1* ]] && O_VER=12cR1 || O_VER=12cR2

case $cfg_db_type in
	std)
		line_separator
		if [ $cfg_dataguard == yes ]
		then
			fake_exec_cmd ./install_grid${O_VER}.sh -db=$db -dg_node=1
			./install_grid${O_VER}.sh -db=$db -dg_node=1
			[ $? -ne 0 ] && exit 1 || true

			timing 20
			LN

			fake_exec_cmd ./install_grid${O_VER}.sh -db=$db -dg_node=2
			./install_grid${O_VER}.sh -db=$db -dg_node=2
			[ $? -ne 0 ] && exit 1 || true
		else
			fake_exec_cmd ./install_grid${O_VER}.sh -db=$db
			./install_grid${O_VER}.sh -db=$db
			[ $? -ne 0 ] && exit 1 || true
		fi
		timing 20
		LN
		;;
	rac)
		line_separator
		fake_exec_cmd ./install_grid${O_VER}.sh -db=$db
		./install_grid${O_VER}.sh -db=$db
		[ $? -ne 0 ] && exit 1 || true
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
			fake_exec_cmd ./install_oracle.sh -db=$db -dg_node=1
			./install_oracle.sh -db=$db -dg_node=1
			[ $? -ne 0 ] && exit 1 || true

			timing 20
			LN

			fake_exec_cmd ./install_oracle.sh -db=$db -dg_node=2
			./install_oracle.sh -db=$db -dg_node=2
			[ $? -ne 0 ] && exit 1 || true
		else
			fake_exec_cmd ./install_oracle.sh -db=$db
			./install_oracle.sh -db=$db
			[ $? -ne 0 ] && exit 1 || true
		fi
		;;
	rac)
		fake_exec_cmd ./install_oracle.sh -db=$db
		./install_oracle.sh -db=$db
		[ $? -ne 0 ] && exit 1 || true
		;;
esac
