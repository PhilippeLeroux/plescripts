#!/bin/sh

#	ts=4 sw=4

#	Exécuter ce script quand le fichier global.cfg est modifié.

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME [-emul]"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

warning "NE PLUS UTILISER TANT QUE LES templates ne seront pas à jour"
exit 1
typeset -r vb_script_templates_path=~/plescripts/virtualbox_template
exit_if_dir_not_exists $vb_script_templates_path

typeset -r shared_directory=$shared_directory/vms_virtualbox
exit_if_dir_not_exists $shared_directory
[ ! -d $shared_directory ] && mkdir $shared_directory

info "Copies des templates :"
exec_cmd cp -f $vb_script_templates_path/*.bat $shared_directory/
LN

function triple_slash
{
	echo "$vm_binary_path" | sed "s!\\\!\\\\\\\\\\\\!g"
}

info "Mise à jour de createvm.bat :"
exec_cmd "sed -i \"s!VIRTUALBOX_PATH!$(triple_slash $vm_binary_path)!\" $shared_directory/createvm.bat"
LN

exec_cmd "sed -i \"s!VIRTUALBOX_VM_PATH!$(triple_slash $vm_path)!\" $shared_directory/createvm.bat"
LN

exec_cmd "sed -i \"s!VIRTUALBOX_LINUX_ISO_PATH!$(triple_slash $full_linux_iso_name)!\" $shared_directory/createvm.bat"
LN

info "Mise à jour de create_mydns_vm.bat :"
exec_cmd "sed -i \"s!DNS_NAME!$dns_hostname!\" $shared_directory/create_mydns_vm.bat"
LN
exec_cmd "sed -i \"s!VM_MEMORY_MB_FOR_DNS!$vm_memory_mb_for_dns!\" $shared_directory/create_mydns_vm.bat"
LN

info "Mise à jour de create_orclmaster.bat :"
exec_cmd "sed -i \"s!MASTER_NAME!$master_name!\" $shared_directory/create_orclmaster.bat"
LN
exec_cmd "sed -i \"s!VM_MEMORY_MB_FOR_MASTER!$vm_memory_mb_for_master!\" $shared_directory/create_orclmaster.bat"
LN
