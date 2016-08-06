#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

typeset vg_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-vg_name=*)
			vg_name=${1##*=}
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

exit_if_param_undef vg_name	"$str_usage"

typeset -r links_file=~/plescripts/san/${vg_name}.link
if [ ! -f $links_file ]
then
	echo "Le fichier $links_file n'existe pas."
	exit 0
fi

typeset -r vg_path=/dev/${vg_name}

[ ! -d $vg_path ] && exec_cmd "mkdir $vg_path"

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

function get_dm_device_for_lv
{
	typeset lv_name=$1
	read perm ilink user group f1 f2 \
		 month time link_name arrow \
		source<<<"$( cat ~/plescripts/san/${vg_name}.link | grep $lv_name )"
	echo "/dev/${source##*/}"
}

connections=$(targetcli / sessions detail)
if [ "$connections" != "(no open sessions)" ]
then
    echo "$connections"
	LN
	info "Stop all connections !"
	exit 1
fi

exec_cmd -c "systemctl stop target"
LN

exec_cmd -c rm -f /etc/target/saveconfig.json

typeset -i count_repaired=0

typeset -r	lvs_file=/tmp/lvs_file.$$

lvs | grep -E "*asm01 .*\-a\-.*$" >$lvs_file
typeset -ri count_errors=$(cat $lvs_file | wc -l)

if [ $count_errors -ne 0 ]
then
	warning "$count_errors errors :"
	while read lv_name vg_n attr size
	do
		info "$lv_name on $vg_n : attr = $RED$attr$NORM size = $size"
		lv_link_name=/dev/$vg_name/$lv_name
		status_link "LV link" $lv_link_name
		ret=$?
		if [ $ret -ne 0 ]
		then
			device=$(get_dm_device_for_lv $lv_name)
			exec_cmd -c "ln -s $device $lv_link_name"
			ret=$?
		fi
		if [ $ret -eq 0 ]
		then
			status_link "LV link created :" $lv_link_name

			dm_link_name=/dev/disk/by-id/dm-name-$vg_name-$lv_name
			status_link "by-id" $dm_link_name
			if [ $? -ne 0 ]
			then
				device=$(readlink -f $lv_link_name)
				info "Create link on $device"
				exec_cmd -c "ln -s $device $dm_link_name"
				[ $? -eq 0 ] && count_repaired=count_repaired+1
				status_link "by-id created :" $dm_link_name
			else
				count_repaired=count_repaired+1
			fi
		fi
		LN
	done < $lvs_file
fi
rm $lvs_file
LN

info "$count_repaired réparations sur $count_errors"
if [ $count_repaired -eq $count_errors ]
then
	exec_cmd "systemctl start target"
	exec_cmd "targetcli clearconfig confirm=true"
	last_backup=$(ls -1 ~/plescripts/san/targetcli_backup/* | tail -1)
	exec_cmd "targetcli restoreconfig $last_backup"
	exec_cmd "targetcli saveconfig"
fi
