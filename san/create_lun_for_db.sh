#!/bin/bash
# vim: ts=4:sw=4

#	Ne pas utiliser directement sert au script : ~/plescripts/clone_master/setup_master.sh

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME
	[-emul]
	[-create_lv]   : les disques sont crées dans le vg définie par -vg_name (1).
	-db=name       : identifiant de la base.
	-node=#        : n° du serveur.
	-vg_name=name  : nom du VG sur le SAN.

(1) Sinon c'est que les LVs existes, ils seront juste exporté sur le réseau.

Ne sert que lors de la création d'un serveur.
Ce script n'est utilisé que par ~/plescripts/database_servers/clone_master.sh"

typeset db=undef
typeset vg_name=undef
typeset create_lv=no
typeset node=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_arg=-emul
			shift
			;;

		-node=*)
			node=${1##*=}
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
			shift
			;;

		-create_lv)
			create_lv=yes
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

exit_if_param_undef db		"$str_usage"
exit_if_param_undef vg_name	"$str_usage"
exit_if_param_undef node	"$str_usage"

typeset -r config_dir=~/plescripts/database_servers/$db
[ ! -d $config_dir ] && error "Directory $config_dir not exists." && exit 1

typeset -r initiator_name=$(get_initiator_for $db $node)

cd ~/plescripts/san

exec_cmd -f ./create_initiator.sh $first_arg	-name=$initiator_name	\
												-user=$db				\
												-password=$oracle_password

while IFS=: read dg_name size_gb first_no last_no
do
	count=$(( $last_no - $first_no + 1 ))

	if [ $create_lv == yes ]
	then
		info "Create $count LVs for DG $dg_name and export LUNs."
		exec_cmd -f ./add_and_export_lv.sh $first_arg	-initiator_name=$initiator_name \
														-vg_name=$vg_name				\
														-prefix=$db						\
														-size_gb=$size_gb				\
														-count=$count					\
														-no_backup
	else
		info "export $count LVs."
		exec_cmd -f ./export_lv.sh $first_arg	-initiator_name=$initiator_name \
												-vg_name=$vg_name				\
												-prefix=$db						\
												-size_gb=$size_gb				\
												-count=$count					\
												-first_no=$first_no				\
												-no_backup
	fi
	LN
done < $config_dir/disks

#	Le nom du bookmark est le nom du serveur.
typeset -r bookmark_name=$(echo $initiator_name | sed "s/.*\(srv.*\):\(.*\)/\1\2/")
info "Create bookmark $bookmark_name"
exec_cmd "targetcli /iscsi/$initiator_name/tpg1/acls/$initiator_name bookmarks add $bookmark_name"
LN

exec_cmd ./save_targetcli_config.sh -name="after_create_luns_for_$db"
LN
