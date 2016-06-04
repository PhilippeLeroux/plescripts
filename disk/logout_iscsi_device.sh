#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME ...."

typeset -i	lun_num=-1

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-lun_num=*)
			lun_num=${1##*=}
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

exit_if_param_undef lun_num	"$str_usage"

#	$1 #lun
function logout_iscsi # $1
{
	typeset -ri lun_num=$1

	typeset -r initiator_name=$(cat /etc/iscsi/initiatorname.iscsi | cut -d'=' -f2)

	iqn=${initiator_name}-lun-$lun_num
	lun_name="ip-${san_ip_priv}:3260-iscsi-$iqn"
	lun_path="/dev/disk/by-path/$lun_name"

	info "logout lun #$lun_num"
	info " -iqn  : $iqn"
	info " -name : $lun_name"
	info " -path : $lun_path"
	LN

	if [ ! -L $lun_path ]
	then
		error "lun #$lun_num not exists."
		exit 1
	fi

	exec_cmd -c "iscsiadm --mode node --target $iqn --portal $san_ip_priv --logout"
	LN
	exec_cmd -c "iscsiadm -m node --target $iqn --portal $san_ip_priv --op update -n node.startup -v manual"
	LN
	exec_cmd -c "iscsiadm -m node --op delete --targetname $iqn"
	LN
}

warning "NE MARCHE PAS !"
logout_iscsi $lun_num

