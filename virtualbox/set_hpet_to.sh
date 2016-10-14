#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/cfglib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-db=name] on|off"

info "Running : $ME $*"

typeset db=undef
typeset	hpet_value=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		on)
			hpet_value=on
			shift
			;;

		off)
			hpet_value=off
			shift
			;;

		-db=*)
			db=${1##*=}
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

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db	"$str_usage"

cfg_exist  $db

typeset -ri	max_nodes=$(cfg_max_nodes $db)
for inode in $( seq $max_nodes )
do
	cfg_load_node_info $db $inode
	info "$cfg_server_name valeur actuelle de hpet :"
	exec_cmd "VBoxManage showvminfo \"$cfg_server_name\" | grep ^HPET"
	LN
	exec_cmd VBoxManage modifyvm "$cfg_server_name" --hpet $hpet_value
	LN
	info "$cfg_server_name nouvelle valeur de hpet :"
	exec_cmd "VBoxManage showvminfo \"$cfg_server_name\" | grep ^HPET"
	LN
done
