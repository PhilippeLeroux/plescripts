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

function infra_ssh
{
	exec_cmd $argv "ssh root@${infra_ip} \"$*\""
}

line_separator
case $type_shared_fs in
	vbox)
		info "Création des points de montage VBox :"
		infra_ssh "mkdir /mnt/plescripts"
		infra_ssh "mount -t vboxsf plescripts /mnt/plescripts"
		infra_ssh "ln -s /mnt/plescripts ~/plescripts"
		;;

	nfs)
		info "Création des points de montage NFS :"
		infra_ssh "mkdir /mnt/plescripts"
		infra_ssh "ln -s /mnt/plescripts ~/plescripts"
		infra_ssh "mount ${infra_network}.1:/home/$common_user_name/plescripts /root/plescripts -t nfs -o ro,$nfs_options"
		infra_ssh "mkdir -p ~/$oracle_install"
		;;
esac
LN

info "Met à jour /etc/hostname avec ${infra_hostname}.${infra_domain}"
infra_ssh "echo \"${infra_hostname}.${infra_domain}\" > /etc/hostname"
LN

if [ ! -f ~/.bashrc_extensions ]
then
	info "Mise en place du fichier ~/.bashrc_extensions"
	infra_ssh "cp ~/plescripts/myconfig/bashrc_extensions ~/.bashrc_extensions"
error "BUG ICI"
if [ 0 -eq 1 ]; then
	cat << EOS >> ~/.bashrc
[ -f ~/.bashrc_extensions ] && . ~/.bashrc_extensions || true
if [ -t 0 ]
then
    typeset -ri count_lv_error=$(lvs 2>/dev/null| grep -E "*asm01 .*\-a\-.*$" | wc -l)

    if [ \$count_lv_error -ne 0 ]
    then
        echo -e "${RED}$count_lv_error lvs errors : poweroff + start!${NORM}"
        systemctl status target -l
        echo ">>>Try to start target<<<"
        systemctl start target
        if [ $? -ne 0 ]
        then
            echo "start failed again."
        else
            echo "C'est bon ??"
        fi
        systemctl status target -l
    fi
fi
EOS
fi # [ 0 -eq 1 ]; then
fi

line_separator
info "Create user $common_user_name"
infra_ssh "useradd -g users -M -N -u 1000 $common_user_name"
LN

line_separator
info "Création des liens symboliques sur les répertoires les plus utilisés."
infra_ssh "ln -s ~/plescripts/san ~/san"
infra_ssh "ln -s ~/plescripts/dns ~/dns"
LN
