#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"

typeset -r str_usage=\
"Usage :
$ME
	-db=name"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
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

exit_if_param_undef db	"$str_usage"

function print_sizes
{
	info "Sizes :"
	fake_exec_cmd "du -sh $ROOT_PATH/*"
	du -sh $ROOT_PATH/*
	LN
	exec_cmd "df -h $ORACLE_BASE"
	LN
}

if [ $gi_count_nodes -gt 1 ]
then
	load_oraenv_for $(srvctl status instance -node $(hostname -s) -db $db	|\
											sed "s/Instance \(.*\) is.*/\1/")
else
	load_oraenv_for $db
fi

typeset	-r	ROOT_PATH=$ORACLE_BASE/diag/rdbms/$db/$ORACLE_SID

exit_if_dir_not_exists "$ROOT_PATH"

print_sizes

info "Purge trace"
fake_exec_cmd "rm -rf $ROOT_PATH/trace/*"
rm -rf $ROOT_PATH/trace/*
LN

info "Purge incident"
fake_exec_cmd "rm -rf $ROOT_PATH/incident/*"
rm -rf $ROOT_PATH/incident/
LN

info "Purge audit"
if [ $gi_count_nodes -gt 1 ]
then
	adump_path="$ORACLE_BASE/admin/$ORACLE_SID/adump"
else
	adump_path="$ORACLE_BASE/admin/$ORACLE_SID/adump"
fi
fake_exec_cmd "rm -rf $adump_path/*"
rm -rf $adump_path/*
LN

print_sizes
