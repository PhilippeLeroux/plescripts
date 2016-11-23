#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-vg_name=name Nom du VG.
	[-all]        Force la restauration de tout les liens du VG.

Restaure les liens manquants, tous si -all est précisé.

La restauration se base sur le fichier san/asm01.link et le dernier fichier de
sauvegarde de target dans le répertoire san/targetcli_backup.
Ces fichiers sont créés par le script ayant en charge la création des LUNs et LVs.

Si une LUN/LV a été créé manuellement, le script ne fonctionnera pas.
"

typeset vg_name=undef
typeset	all=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
			shift
			;;

		-all)
			all=yes
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

exit_if_param_undef vg_name	"$str_usage"

#	Nom du dernier backup de target.
typeset	-r last_target_backup=$(ls -1 ~/plescripts/san/targetcli_backup/* | tail -1)

#	Fichier de backup des liens.
typeset -r links_file=~/plescripts/san/${vg_name}.link

#	Contiendra la liste des liens à réparer.
typeset -r	links_2_repair=/tmp/links_2_repair.$$

typeset -r vg_path=/dev/${vg_name}

#	$1	message
#	$2	link
#	return 0 if link exists else 1
function status_link #prefix link
{
	if [ -L $2 ]
	then
		info "$1 $2 $OK"
		return 0
	else
		info "$1 $2 $KO"
		return 1
	fi
}

#	$1	LV name
#	return associate device.
function get_dm_device_for_lv
{
	typeset lv_name=$1
	read perm ilink user group f1 f2 \
		 month time link_name arrow \
		source<<<"$( cat ~/plescripts/san/${vg_name}.link | grep $lv_name )"
	echo "/dev/${source##*/}"
}

function make_file_list_links
{
	lvs | grep -E "*asm01 .*\-a\-.*$" >$links_2_repair
}

#	Vérifie si les fichies nécessaires à la restaurations existes.
function test_backup_files
{
	typeset	exit=no

	if [ x"$last_target_backup" == x ]
	then
		error "No backup file found for target."
		exit=yes
	fi

	if [ ! -f $links_file ]
	then
		error "File $links_file not exist."
		exit=yes
	fi

	[ $exit == yes ] && exit 1
}

function test_no_connections_on_target
{
	connections=$(targetcli / sessions detail)
	if [ "$connections" != "(no open sessions)" ]
	then
		echo "$connections"
		LN
		info "Stop all connections !"
		exit 1
	fi
}

test_backup_files

test_no_connections_on_target

[ ! -d $vg_path ] && exec_cmd "mkdir $vg_path"

#	Il faut lire les links en erreur avant l'arrêt de target.
if [ $all == no ]
then
	make_file_list_links
	typeset -ri	count_errors=$(cat $links_2_repair | wc -l)
	if [ $count_errors -eq 0 ]
	then
		info "No error."
		LN
		exit 0
	fi
fi

info "Stop target and remove its configuration."
exec_cmd -c "systemctl stop target"
exec_cmd -c rm -f /etc/target/saveconfig.json
LN

#	Pour lire tous les liens il faut que target soit stoppé.
if [ $all == yes ]
then
	make_file_list_links
	typeset -ri	count_errors=$(cat $links_2_repair | wc -l)
	if [ $count_errors -eq 0 ]
	then
		info "File $links_2_repair empty ?"
		LN
		exit 0
	fi
fi

if [ $all == no ]
then
	warning "VG $vg_name error : $count_errors links."
else
	info "Restore all links for VG $vg_name"
fi
LN

typeset -i	count_repaired=0
while read lv_name vg_n attr size
do
	info "$lv_name on $vg_n : attr = $RED$attr$NORM size = $size"
	lv_link_name=/dev/$vg_name/$lv_name
	status_link "LV link" $lv_link_name
	lv_link_status=$?
	if [ $lv_link_status -ne 0 ]
	then
		info "Create link $lv_link_name"
		device=$(get_dm_device_for_lv $lv_name)
		exec_cmd -c "ln -s $device $lv_link_name"
		status_link "LV link created : " $lv_link_name
		lv_link_status=$?
	fi

	if [ $lv_link_status -eq 0 ]
	then
		dm_link_name=/dev/disk/by-id/dm-name-$vg_name-$lv_name
		status_link "by-id" $dm_link_name
		if [ $? -ne 0 ]
		then
			device=$(readlink -f $lv_link_name)
			info "Create link on $device"
			exec_cmd -c "ln -s $device $dm_link_name"
			status_link "by-id created :" $dm_link_name
			[ $? -eq 0 ] && count_repaired=count_repaired+1
		else
			count_repaired=count_repaired+1
		fi
	fi
	LN
done < $links_2_repair
rm $links_2_repair
LN

info "$count_repaired links repaired on $count_errors errors"
if [ $count_repaired -eq $count_errors ]
then
	exec_cmd "systemctl start target"
	exec_cmd "targetcli clearconfig confirm=true"
	exec_cmd "targetcli restoreconfig $last_target_backup"
	exec_cmd "targetcli saveconfig"
fi
