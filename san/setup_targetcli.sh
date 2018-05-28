#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

# Le script ne test pas le nom du serveur, lors de la création du serveur d'infra
# le nom du serveur est toujours celui du master.
typeset	-r	str_usage=\
"Usage : $ME

Le script doit être exécuté sur le serveur $infra_hostname.

Configure targetcli pour pouvoir exporter des LV sur le réseau $if_iscsi_network/$if_iscsi_prefix.
Le protocole iSCSI est utilisé. targetcli gérant l'export des LUN.

Un VG $infra_vg_name_for_db_luns de ${san_disk_size_g}Gb sera créé.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
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

if [ 0 -eq 1 ]
then # Les tests ont montré plus d'erreurs avec cette préco appliquée.
line_separator
info "Update lvm conf (Datera preco)"
exec_cmd 'sed -i "s/write_cache_state =.*/write_cache_state = 0/" /etc/lvm/lvm.conf'
exec_cmd 'sed -i "s/readahead =.*/readahead = \"none\"/" /etc/lvm/lvm.conf'
LN
fi # [ 0 -eq 1 ]

line_separator
info "Create VG $infra_vg_name_for_db_luns on first unused disk :"
exec_cmd ~/plescripts/san/create_vg.sh					\
						-device=auto					\
						-vg=$infra_vg_name_for_db_luns	\
						-add_partition=no				\
						-io_scheduler=cfq
LN

line_separator
info "Setup SAN"
exec_cmd "~/plescripts/san/targetcli_default_cfg.sh"
LN

line_separator
info "Workaround target error"
exec_cmd cp ~/plescripts/setup_first_vms/check-target.service	\
			/usr/lib/systemd/system/check-target.service
exec_cmd systemctl enable check-target.service
LN
