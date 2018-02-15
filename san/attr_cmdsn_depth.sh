#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/san/targetclilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

typeset	-r	str_usage=\
"Usage :
$ME
	-db=name   To update or show all db : -db=all
	[-show]
	[-value=#] Mandatory if no flag show

update attribute default_cmdsn_depth.
"

typeset		db=undef
typeset		action=update
typeset	-i	value=-1

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

		-show)
			action=show
			shift
			;;

		-value=*)
			value=${1##*=}
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

# $1 current | updated
function show_attr
{
	line_separator
	info "Show $1 value"
	LN

	for (( inode=1; inode <= max_nodes; ++inode ))
	do
		initiator_name=$(get_initiator_for $db $inode)
		exec_cmd targetcli /iscsi/$initiator_name/tpg1 get attribute default_cmdsn_depth
		LN
	done
}

function update_attr
{
	line_separator
	info "Update value"
	LN

	for (( inode=1; inode <= max_nodes; ++inode ))
	do
		initiator_name=$(get_initiator_for $db $inode)
		exec_cmd targetcli /iscsi/$initiator_name/tpg1 set attribute default_cmdsn_depth=$value
		LN
	done

	show_attr updated
}

function do_it
{
	cfg_exists $db

	typeset	-ri	max_nodes=$(cfg_max_nodes $db)

	show_attr current

	[ $action == update ] && update_attr || true
}

exit_if_param_undef db	"$str_usage"
[ $action == update ] && exit_if_param_undef value	"$str_usage" || true

must_be_user root
must_be_executed_on_server $infra_hostname

if [ $db == all ]
then
	while read fullpath
	do
		db=${fullpath##*/}
		[ x"$db" == x ] && continue || true
		do_it
	done<<<"$(find ~/plescripts/database_servers/ -type d)"

	if [ $action == update ]
	then
		line_separator
		info "Save targetcli config."
		LN
		exec_cmd ~/plescripts/san/save_targetcli_config.sh -name=update_all_default_cmdsn_depth
	fi
else
	do_it

	if [ $action == update ]
	then
		line_separator
		info "Save targetcli config."
		LN
		exec_cmd ~/plescripts/san/save_targetcli_config.sh -name=update_${db}_default_cmdsn_depth
	fi
fi
