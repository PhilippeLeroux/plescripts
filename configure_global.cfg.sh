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

if [ 0 -eq 1 ]; then
typeset hostvm_type=undef
info "Select hypervisor :"
info "	1 : vbox for linux"
while [ 0 -eq 0 ] # forever
do
	read -s -n 1 keyboard
	case $keyboard in
		1)	LN
			info "==> VirtualBox for Linux"
			hostvm_type=linux_virtualbox
			full_linux_iso_n="$HOME/ISO/oracle_linux_7/V100082-01.iso"
			break
			;;

		*)	error "$keyboard invalid."
		;;
	esac
done
LN
else
	hostvm_type=linux_virtualbox
	full_linux_iso_n="$HOME/ISO/oracle_linux_7/V100082-01.iso"
fi # [ 0 -eq 1 ]; then

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
	fi
	read -r keyboard

	[ x"$keyboard" != x ] && var_value="$keyboard"

	#var_value=$(escape_anti_slash $var_value)
	#var_value=$(escape_slash "$var_value")

	eval "$var_name=$(echo -E '$var_value')"
}

vm_p="$(VBoxManage list systemproperties | grep "Default machine folder:" | tr -s [:space:] | cut -d' ' -f4-)"
ask_for_variable vm_p "VMs folder :"

ask_for_variable full_linux_iso_n "Full path for Oracle Linux 7 ISO (...V100082-01.iso) :"

line_separator
exec_cmd "sed -i 's/hostvm=.*$/hostvm=$hostvm_type/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/client_hostname=.*/client_hostname=$(hostname -s)/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's/common_user_name=.*/common_user_name=$USER/g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's/common_uid=.*/common_uid=$UID/g' ~/plescripts/global.cfg"
LN

exec_cmd "sed -i 's~vm_path=.*$~vm_path=\"$vm_p\"~g' ~/plescripts/global.cfg"
LN

iso_path=${full_linux_iso_n%/*}
iso_name=${full_linux_iso_n##*/}
exec_cmd "sed -i 's~iso_olinux_path=.*$~iso_olinux_path=\"$iso_path\"~g' ~/plescripts/global.cfg"
exec_cmd "sed -i 's~full_linux_iso_name=.*$~full_linux_iso_name=\"\$iso_olinux_path/$iso_name\"~g' ~/plescripts/global.cfg"
LN
