#!/bin/sh
#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r str_usage=\
"Usage : $ME [-emul]"

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

function run_ssh
{
	exec_cmd "ssh root@$infra_ip \"$@\""
}

line_separator
info "Arrêt de la VM $master_name"
exec_cmd -c VBoxManage controlvm $master_name acpipowerbutton
[ $? -eq 0 ] && ( info -n "Attend l'arrêt complet : "; pause_in_secs 20; LN )

line_separator
info "Clonage de la VM master."
exec_cmd VBoxManage clonevm $master_name --name $infra_hostname --basefolder \"$vm_path\" --register
LN

line_separator
info "Ajout d'une carte pour la connexion internet."
exec_cmd VBoxManage modifyvm $infra_hostname --nic3 bridged
exec_cmd VBoxManage modifyvm $infra_hostname --bridgeadapter3 "enp3s0"
exec_cmd VBoxManage modifyvm $infra_hostname --nictype3 virtio
LN

line_separator
info "Ajout d'un disque pour le SAN (targetcli)"
exec_cmd VBoxManage createhd --filename \"$vm_path/$infra_hostname/asm01.vdi\" --size 524288
exec_cmd VBoxManage storageattach $infra_hostname --storagectl SATA --port 1 --device 0 --type hdd --medium \"$vm_path/$infra_hostname/asm01.vdi\"
LN

line_separator
info "Ajoute $infra_hostname au groupe Infra"
exec_cmd VBoxManage modifyvm "$infra_hostname" --groups "/Infra"
LN

line_separator
exec_cmd "VBoxManage showvminfo $infra_hostname > $infra_hostname.info"
LN

line_separator
info "Démarre la VM $infra_hostname"
exec_cmd VBoxManage startvm  $infra_hostname --type headless
info -n "Temporisation : "; pause_in_secs 40; LN
LN

line_separator
info "Copie la configuration des Ifaces sur $infra_hostname"
exec_cmd "scp ~/plescripts/setup_first_vms/ifcfg_infra_server/* root@192.170.100.2:/etc/sysconfig/network-scripts/"
LN

line_separator
info "Redémarrage de la VM $infra_hostname"
exec_cmd VBoxManage controlvm $infra_hostname acpipowerbutton
info -n "Temporisation : "; pause_in_secs 20; LN
exec_cmd VBoxManage startvm $infra_hostname --type headless
info -n "Temporisation : "; pause_in_secs 40; LN

line_separator
info "Connexion ssh :"
exec_cmd "~/plescripts/shell/connections_ssh_with.sh -user=root -server=$infra_ip"
LN

line_separator
run_ssh "mkdir plescripts"
run_ssh "mount 192.170.100.1:/home/$common_user_name/plescripts /root/plescripts"
run_ssh "mkdir -p ~/$oracle_install"
run_ssh "mkdir zips"
run_ssh "mount 192.170.100.1:/home/kangs/ISO/$oracle_install /root/zips"
run_ssh "~/plescripts/setup_first_vms/02_update_config.sh"
run_ssh "~/plescripts/setup_first_vms/03_setup_infra_or_master.sh -role=infra"
run_ssh "~/plescripts/setup_first_vms/04_unzip_oracle_cd.sh"
LN

line_separator
info "Configure DNS"
run_ssh "~/plescripts/dns/install/01_install_bind.sh"
run_ssh "~/plescripts/dns/install/03_configure.sh"

run_ssh "~/plescripts/dns/add_server_2_dns.sh -name=$client_hostname -ip_node=1"
run_ssh "~/plescripts/dns/add_server_2_dns.sh -name=orclmaster -ip_node=$master_ip_node"
run_ssh "~/plescripts/dns/show_dns.sh"

line_separator
run_ssh "~/plescripts/shell/set_plymouth_them"
LN

line_separator
info "Redémarrage de la VM $infra_hostname"
exec_cmd VBoxManage controlvm $infra_hostname acpipowerbutton
info -n "Temporisation : "; pause_in_secs 20; LN

line_separator
info "Ajuste la RAM"
exec_cmd VBoxManage modifyvm $infra_hostname --memory $vm_memory_mb_for_infra
LN

exec_cmd VBoxManage startvm $infra_hostname --type headless
info -n "Temporisation : "; pause_in_secs 40; LN
exec_cmd "~/plescripts/shell/connections_ssh_with.sh -user=root -server=K2"
LN
