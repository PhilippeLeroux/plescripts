#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

info "Running : $ME $*"

typeset argv
[ "$DEBUG_MODE" == ENABLE ] && argv="-c"

function master_ssh
{
	debug "ssh connection from $(hostname -s) to $master_ip"
	exec_cmd $argv "ssh root@${master_ip} \"$*\""
}

line_separator
case $type_shared_fs in
	vbox)
		info "Création des points de montage VBox :"
		master_ssh "mkdir /mnt/plescripts"
		master_ssh "mount -t vboxsf plescripts /mnt/plescripts"
		master_ssh "ln -s /mnt/plescripts ~/plescripts"
		;;

	nfs)
		info "Création des points de montage NFS :"
		master_ssh "mkdir /mnt/plescripts"
		master_ssh "ln -s /mnt/plescripts ~/plescripts"
		master_ssh "mount ${infra_network}.1:/home/$common_user_name/plescripts /root/plescripts -t nfs -o ro,_netdev,$nfs_options"
		master_ssh "mkdir -p ~/$oracle_install"
		;;
esac
LN

info "Mise en place du fichier ~/.bashrc_extensions"
master_ssh "cp ~/plescripts/myconfig/bashrc_extensions ~/.bashrc_extensions"

line_separator
info "Create user $common_user_name"
master_ssh "useradd -g users -M -N -u 1000 $common_user_name"
LN

line_separator
info "Configuration du dépôt"
# TODO rendre configurable le nom du fichier !
master_ssh "cp -fp ~/plescripts/yum/public-yum-ol7.repo /etc/yum.repos.d/public-yum-ol7.repo"
LN
master_ssh "mkdir -p /mnt$infra_olinux_repository_path"
master_ssh "echo \"$infra_hostname:$infra_olinux_repository_path /mnt$infra_olinux_repository_path nfs ro,$nfs_options 0 0\" >> /etc/fstab"
master_ssh mount /mnt$infra_olinux_repository_path
LN
