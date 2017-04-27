#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
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
#	Pré sélection de l'image Oracle Linux 7
typeset -r OracleLinux72=V100082-01.iso
typeset -r OracleLinux73=V834394-01.iso

full_linux_iso_n="$HOME/ISO/oracle_linux_7/$OracleLinux72"
OL7_LABEL_n=7.2

if [ 0 -eq 1 ]; then
# Oracle Linux 7.3 ne fonctionne pas du tout, java par en core dump plus autre
# joyeusetées.
full_linux_iso_n="$HOME/ISO/oracle_linux_7/$OracleLinux73"
OL7_LABEL_n=7.3
fi
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
		info "Press <enter> to select : $str"
		info -n "Or new value : "
	else
		info -n "Value : "
	fi
	read -r keyboard

	[ x"$keyboard" != x ] && var_value="$keyboard"

	#var_value=$(escape_anti_slash $var_value)
	#var_value=$(escape_slash "$var_value")

	eval "$var_name=$(echo -E '$var_value')"
}

function read_gateway_ip
{
	typeset outp=$(cat /etc/resolv.conf | grep -E "^nameserver")
	if [ $(wc -l<<<"$outp") -eq 1 ]
	then
		cut -d\  -f2<<<"$outp"
	else
		echo $gateway
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
		info -n "Exists $vm_p : "
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
		LN
	fi
}

function Oracle_Linux_ISO
{
	ask_for_variable full_linux_iso_n "Full path for Oracle Linux $OL7_LABEL_n ISO $OracleLinux72 :"
	info -n "Exists $full_linux_iso_n : "
	if [ ! -f "$full_linux_iso_n" ]
	then
		((++count_errors))
		info -f "[$KO]"
		LN
	else
		info -f "[$OK]"
		LN
	fi
}

function yum_repository
{
	info "Oracle Linux release."
	if [ "$common_user_name" == "$USER" ]
	then # global.cfg a déjà été configuré.
		ol7=$orcl_yum_repository_release
	else
		ol7=DVD
	fi
	ask_for_variable ol7 "Oracle Linux 7.2 select DVD, Oracle Linux 7.3 select internet"
	LN
	case "$(to_upper $ol7)" in
		DVD)
			ol7=DVD_R2
			;;
		INTERNET)
			ol7=R3
			;;
		R3)
			: # OK
			;;
		R4)
			warning "R4 la 12.1 ne s'installe pas."
			LN
			;;
		*)
			error "$ol7 invalid."
			LN
			((++count_errors))
			;;
	esac
}

function configure_gateway
{
	gateway_new_ip=$(read_gateway_ip)
	ask_for_variable gateway_new_ip "Gateway IP (Box address) :"
	info -n "Ping $gateway_new_ip"
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
	info "Network interface"
	exec_cmd "ip link show | grep -vE \"(lo|vboxnet)\" | grep \"state UP\""
	LN
	if_net_bridgeadapter_n=$(printf "%s" $(ip link show | grep -vE "(lo|vboxnet)" | grep "state UP" | head -1 | cut -d: -f2))
	ask_for_variable if_net_bridgeadapter_n "Network interface to used for internet access."
	LN
}

typeset -i count_errors=0

VMs_folder

Oracle_Linux_ISO

yum_repository

configure_gateway

LUNs_storage

network_interface

if [ $count_errors -ne 0 ]
then
	error "$count_errors errors, configuration not updated !"
	LN
	exit 1
fi

line_separator
exec_cmd "sed -i 's/gateway=.*$/gateway=$gateway_new_ip/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/hostvm=.*$/hostvm=$hostvm_type/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/client_hostname=.*/client_hostname=$(hostname -s)/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/common_user_name=.*/common_user_name=$USER/g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's/common_uid=.*/common_uid=$UID/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/if_net_bridgeadapter=.*/if_net_bridgeadapter=$if_net_bridgeadapter_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's~vm_path=.*$~vm_path=\"\${VM_PATH:-$vm_p}\"~g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's~disks_hosted_by=.*$~disks_hosted_by=\${DISKS_HOSTED_BY:-$disks_stored_on}~g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's~san_disk=.*$~san_disk=\${SAN_DISK_TYPE:-$san_disk_type}~g' ~/plescripts/global.cfg"
LN

if [ "$HOME/ISO/oracle_linux_7/$OracleLinux73" == "$full_linux_iso_n" ]
then
	OL7_LABEL_n=7.3
	line_separator
	error "Oracle Linux $OL7_LABEL_n don't work."
	error "Latest tested Release is Oracle Linux 7.2 ISO : $OracleLinux72"
	LN
else
	OL7_LABEL_n=7.2
fi

info "Setup Oracle Linux $OL7_LABEL_n"
iso_path=${full_linux_iso_n%/*}
iso_name=${full_linux_iso_n##*/}
exec_cmd "sed -i 's/OL7_LABEL=.*/OL7_LABEL=$OL7_LABEL_n/g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's~iso_olinux_path=.*$~iso_olinux_path=\"$iso_path\"~g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's~full_linux_iso_name=.*$~full_linux_iso_name=\"\$iso_olinux_path/$iso_name\"~g' ~/plescripts/global.cfg"
LN

info "Configure repository OL7"
exec_cmd "sed -i 's/infra_yum_repository_release=.*/infra_yum_repository_release=$ol7/g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's/master_yum_repository_release=.*/master_yum_repository_release=$ol7/g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's/orcl_yum_repository_release=.*/orcl_yum_repository_release=\${ORCL_YUM_REPOSITORY_RELEASE:-$ol7}/g' ~/plescripts/global.cfg"
LN


