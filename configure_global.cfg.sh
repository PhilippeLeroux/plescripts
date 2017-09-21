#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r PARAMS="$*"
typeset -r str_usage=\
"Usage : $ME ...."

typeset db=undef

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

typeset -r hostvm_type=linux_virtualbox

#	============================================================================

#	$1 nom de la variable à renseigner
#	$2 Message à afficher
function ask_for_variable
{
	typeset -r 	var_name=$1
	typeset		var_value=$(eval echo \$$var_name)
	typeset -r 	msg=$2

	info "$msg"
	if [ x"$var_value" != x ]
	then
		str=$(escape_anti_slash "$var_value")
		info "Press <enter> to select : $(replace_paths_by_shell_vars $str)"
		info -n "Or new value : "
	else
		info -n "Value : "
	fi
	read -r keyboard

	[ x"$keyboard" != x ] && var_value="$keyboard"

	eval "$var_name=$(echo -E '$var_value')"
}

function read_gateway_ip
{
	typeset outp=$(cat /etc/resolv.conf|grep -E "^nameserver")
	if [ $(wc -l<<<"$outp") -eq 1 ]
	then
		cut -d\  -f2<<<"$outp"
	else # Plus de 1 serveur, supprime l'IP de l'infra si elle est présente.
		outp=$(grep -vE "$infra_ip"<<<"$outp")
		if [ $(wc -l<<<"$outp") -eq 1 ]
		then
			cut -d\  -f2<<<"$outp"
		else # # Plus de 1 serveur, l'utilisateur corrigera au besoins.
			echo $gateway	# Variable définie dans global.cfg
		fi
	fi
}

function VMs_folder
{
	if test_if_cmd_exists VBoxManage
	then
		if [ "$common_user_name" == "$USER" ]
		then # global.cfg a déjà été configuré.
			vm_p="$vm_path"
		else
			vm_p="$(VBoxManage list systemproperties	|\
						grep "Default machine folder:"	|\
						tr -s [:space:] | cut -d' ' -f4-)"
		fi

		ask_for_variable vm_p "VMs folder :"
		info -n "Exists $(replace_paths_by_shell_vars $vm_p) : "
		if [ ! -d "$vm_p" ]
		then
			((++count_errors))
			info -f "[$KO]"
			LN
		else
			info -f "[$OK]"
			LN
		fi
	else
		error "VirtualBox not installed or VBoxManage not in PATH"
		((++count_errors))
		vm_p="No VMs folder"
		LN
	fi
}

function Oracle_Linux_Release
{
	OL7_LABEL_n=$OL7_LABEL
	ask_for_variable OL7_LABEL_n "Oracle Linux release : 7.2, 7.3, 7.4 :"
	LN

	case $OL7_LABEL_n in
		7.2|7.3|7.4)
			;;
		*)
			((++count_errors))
			error "Release $OL7_LABEL_n invalid."
			LN
	esac
}

function Oracle_Linux_ISO
{
	case "$OL7_LABEL_n" in
	"7.2")
		full_linux_iso_n="$iso_olinux_path/V100082-01.iso"
		;;

	"7.3")
		full_linux_iso_n="$iso_olinux_path/V834394-01.iso"
		;;

	"7.4")
		full_linux_iso_n="$iso_olinux_path/V921569-01.iso"
		;;
	esac

	info -n "Exists $(replace_paths_by_shell_vars $full_linux_iso_n) : "
	if [ ! -f "$full_linux_iso_n" ]
	then
		((++count_errors))
		info -f "[$KO] : download Oracle Linux ISO."
		LN
	else
		info -f "[$OK]"
		LN
	fi
}

function yum_repository
{
	# Il n'est pas possible de rester sur une ancienne release. Donc pour
	# avoir du R2 ou R3 dépôt depuis le DVD.
	case $OL7_LABEL_n in
		7.2)
			ol7_repository_release=DVD_R2
			return 0
			;;
		7.3)
			ol7_repository_release=DVD_R3
			return 0
			;;
		7.4)
			typeset do_update=yes
			ask_for_variable do_update "Update Oracle Linux $OL7_LABEL_n release ? yes no"
			do_update=$(to_lower $do_update)
			LN

			if [ $do_update == yes ]
			then
				ol7_repository_release=R4
			else
				ol7_repository_release=DVD_R4
			fi
			return 0
			;;
	esac

	return 1
}

function configure_gateway
{
	gateway_new_ip=$(read_gateway_ip)
	ask_for_variable gateway_new_ip "Gateway IP (Box address) :"
	info -n "Ping $gateway_new_ip "
	if ping -c 1 $gateway_new_ip 1>/dev/null 2>&1
	then
		info -f "[$OK]"
		LN
	else
		((++count_errors))
		info -f "[$KO]"
		LN
	fi
}

function LUNs_storage
{
	disks_stored_on=$disks_hosted_by
	ask_for_variable disks_stored_on "Disks managed by san or vbox (vbox = VirtualBox) :"
	LN
	disks_stored_on=$(to_lower $disks_stored_on)
	case "$disks_stored_on" in
		vbox|san)
			;;
		*)
			((++count_errors))
			error "Value $disks_stored_on invalid."
			LN
			;;
	esac

	if [ "$common_user_name" != "$USER" ]
	then # global.cfg n'a jamais été configuré.
		san_disk_type=vdi
	elif [ -b $san_disk ]
	then
		san_disk_type=$san_disk
	else
		san_disk_type=vdi
	fi
	ask_for_variable san_disk_type	\
		"Use virtual disk (enter vdi) or physical disk (enter full device name) : "
	LN

	if [ "$san_disk_type" != "vdi" ]
	then
		info -n "Device $san_disk_type exists : "
		if [ ! -b "$san_disk_type" ]
		then
			((++count_errors))
			info -f "[$KO]"
			LN
		else
			info -f "[$OK]"
			LN
			warning "All data on $san_disk_type will be lost !"
			confirm_or_exit "Continue"
			LN

			typeset -r device_group=$(ls -l "$san_disk" | cut -d\  -f4)
			info "$san_disk in group : $device_group"
			info -n "$USER member of group : $device_group "
			if id | grep -q $device_group
			then
				info -f "[$OK]"
				LN
			else
				info -f "[$KO] add $USER to group $device_group"
				exec_cmd sudo usermod -a -G $device_group $USER
				LN
				error "Disconnect & connect user $USER"
				((++count_errors))
				LN
			fi

		fi
	fi
}

function network_interface
{
	info "Network interfaces"
	exec_cmd "ip link show | grep -vE \"(lo|vboxnet)\" | grep \"state UP\""
	LN
	if_net_bridgeadapter_n=$(printf "%s" $(ip link show | grep -vE "(lo|vboxnet)" | grep "state UP" | head -1 | cut -d: -f2))
	ask_for_variable if_net_bridgeadapter_n "Network interface to used for internet access."
	LN
}

# update file $HOME/plescripts/local.cfg if $1 != $2
# $1 orignal value
# $2 new value
# $3 parameter name to write to local cfg
function add_to_local_cfg
{
	if [ "$1" != "$2" ]
	then
		info "local.cfg : update $3 = $2"
		update_value "$3" "$2" $HOME/plescripts/local.cfg
		LN
	fi
}

typeset -i count_errors=0

VMs_folder

Oracle_Linux_Release

yum_repository

Oracle_Linux_ISO

configure_gateway

LUNs_storage

network_interface

if [ ! -d $HOME/plescripts/tmp ]
then
	info "Create temporary directory."
	exec_cmd "mkdir $HOME/plescripts/tmp"
	LN
fi

line_separator
add_to_local_cfg "$gateway" "$gateway_new_ip" GATEWAY

add_to_local_cfg "$hostvm" "$hostvm_type" HOSTVM

add_to_local_cfg "$client_hostname" "$(hostname -s)" CLIENT_HOSTNAME

add_to_local_cfg "$common_user_name" "$USER" COMMON_USER_NAME

add_to_local_cfg "$common_uid" "$UID" COMMON_UID

add_to_local_cfg "$if_net_bridgeadapter" "$if_net_bridgeadapter_n" IF_NET_BRIDGEADAPTER

add_to_local_cfg "xxxx" "\"$vm_p\"" VM_PATH

if [ "$disks_hosted_by" != "$disks_stored_on" ]
then
	update_value "DISKS_HOSTED_BY" "$DISKS_HOSTED_BY" ~/plescripts/local.cfg
	update_value "SAN_DISK" "$san_disk_type" ~/plescripts/local.cfg
	LN
fi

add_to_local_cfg "$OL7_LABEL" "$OL7_LABEL_n" OL7_LABEL

info "Configure repository OL7"
if	[[ $OL7_LABEL_n == 7.4 && $ol7_repository_release != R4 ]] ||	\
	[[ $OL7_LABEL_n == 7.3 && $ol7_repository_release != R3 ]] ||	\
	[[ $OL7_LABEL_n == 7.2  ]]
then
	update_value "INFRA_YUM_REPOSITORY_RELEASE" "$ol7_repository_release" ~/plescripts/local.cfg
	update_value "ORCL_YUM_REPOSITORY_RELEASE" "$ol7_repository_release" ~/plescripts/local.cfg
	LN
fi

if [ $count_errors -ne 0 ]
then
	error "$count_errors errors."
	error "Correct all errors and rerun this script."
	LN
	exit 1
fi

exit 0
