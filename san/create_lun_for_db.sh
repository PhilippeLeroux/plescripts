#!/bin/bash

#	ts=4 sw=4

#	Ne pas utiliser directement sert au script : ~/plescripts/clone_master/setup_master.sh
#	TODO : déplacer ce script !!!!!

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME [-emul]
		[-create_disk] : les disques seront crées dans le vg asm01
		-db=<str>      : identifiant de la base.
		-node=<#>      : n° du serveur.

Ne sert que lors de la création d'un serveur.
Ce script n'est utilisé que par ~/plescripts/database_servers/clone_master.sh"

typeset db=undef
typeset create_disk=no
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

		-create_disk)
			create_disk=yes
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

	info "Create $count LVs for DG $dg_name"
	LN

	if [ $create_disk = yes ]
	then
		info "Create disks for DG $dg_name and export LVs."
		exec_cmd -f ./add_and_export_lv.sh $first_arg	-initiator_name=$initiator_name \
														-vg_name=asm01					\
														-prefix=$db						\
														-size_gb=$size_gb				\
														-count=$count					\
														-no_backup
	else
		info "export LV."
		info "$count disks start at $first_no"
		exec_cmd -f ./export_lv.sh $first_arg	-initiator_name=$initiator_name \
												-vg_name=asm01					\
												-prefix=$db						\
												-size_gb=$size_gb				\
												-count=$count					\
												-first_no=$first_no				\
												-no_backup
	fi
	LN
done < $config_dir/disks

exec_cmd ./save_targetcli_config.sh -name="after_create_luns_for_$db"
