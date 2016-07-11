#!/bin/bash

#	ts=4	sw=4

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
			first_args=-emul
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

typeset hostvm_type=undef
info "Select hypervisor :"
info "	1 : vbox for linux"
info "	2 : vbox for windows"
info "	x : other"
while [ 0 -eq 0 ] # forever
do
	read -s -n 1 keyboard
	case $keyboard in
		1)	LN
			info "==> VirtualBox for Linux"
			hostvm_type=linux_virtualbox
			client_h=$(hostname -s)
			common_user_n=$USER
			vm_p="\$HOME/VirtualBox VMs"
			full_linux_iso_n="\$HOME/ISO/oracle_linux_7/V100082-01.iso"
			break;
			;;

		2)	LN
			info "N'est plus à jour"
			exit 0
			info "==> VirtualBox for Windows"
			hostvm_type=windows_virtualbox
			vm_p="C:\Users\kangs\VirtualBox VMs"
			full_linux_iso_n="C:\Users\kangs\Desktop\iso_linux\V100082-01.iso"
			break;
			;;

		x)	LN
			warning "No scripts provided to create VMs."
			warning "And you must configure global.cfg manually !"
			exit 0
			hostvm_type=unknow
			break;
			;;

		*)	error "$keyboard invalid."
		;;
	esac
done
LN

#	$1 nom de la variable à renseigner
#	$2 Message à afficher
function ask_for
{
	typeset -r 	var_name=$1
	typeset		var_value=$(eval echo \$$var_name)
	typeset -r 	msg=$2

	info "$msg"
	if [ x"$var_value" != x ]
	then
		str=$(escape_anti_slash "$var_value")
		info "Press <enter> to select : $str"
	fi
	read -r keyboard

	[ x"$keyboard" != x ] && var_value="$keyboard"

	#var_value=$(escape_anti_slash $var_value)
	#var_value=$(escape_slash "$var_value")

	eval "$var_name=$(echo -E '$var_value')"
}

ask_for vm_p "Localisation des VMs :"

ask_for full_linux_iso_n "Full path for Oracle Linux 7 ISO (...V100082-01.iso) :"

line_separator
if [ $hostvm_type != unknow ]
then
	exec_cmd "sed -i 's/hostvm=.*$/hostvm=$hostvm_type/g' ~/plescripts/global.cfg"
	LN
fi

exec_cmd "sed -i 's/client_hostname=.*/client_hostname=$client_h/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/common_user_name=.*/common_user_name=$common_user_n/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's~vm_path=.*$~vm_path=\"$vm_p\"~g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's~full_linux_iso_name=.*$~full_linux_iso_name=\"$full_linux_iso_n\"~g' ~/plescripts/global.cfg"
LN
