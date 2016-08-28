#!/bin/bash

# vim: ts=4:sw=4

typeset -r ME=$0

. ~/plescripts/plelib.sh
EXEC_CMD_ACTION=EXEC

error "NE PLUS UTILISER !"
exit 1

function print_error_and_exit
{
    if [ $# -ne 0 ]
    then
        error "$@"
    fi

    info "Usage : $ME -hostname=<new hostname>"
    exit 1
}

typeset -r current_host=`hostname -s`

if [ "$current_host" = "oratemplate" ]
then
	error "Le nom du serveur n'a pas été renomé."
	exit 1
fi

typeset -r OLD_VG_NAME=vg_oratemplate
typeset -r NEW_VG_NAME=vg_${current_host}

function rename_vg
{
	info "Renomme le vg '$OLD_VG_NAME' en '$NEW_VG_NAME'"
	exec_cmd vgrename $OLD_VG_NAME $NEW_VG_NAME
}

function update_fstab_and_grub
{
	exec_cmd "sed \"s/$OLD_VG_NAME/$NEW_VG_NAME/g\" /etc/fstab > /tmp/fstab"
	exec_cmd "sed \"s/$OLD_VG_NAME/$NEW_VG_NAME/g\" /boot/grub/grub.conf > /tmp/grub.conf"

	exec_cmd "mv /tmp/fstab /etc/fstab"
	exec_cmd "mv /tmp/grub.conf /boot/grub/grub.conf"
}

function update_initramfs
{
	exec_cmd mkinitrd --force /boot/initramfs-2.6.32-279.el6.x86_64.img 2.6.32-279.el6.x86_64
	exec_cmd mkinitrd --force /boot/initramfs-2.6.39-200.24.1.el6uek.x86_64.img 2.6.39-200.24.1.el6uek.x86_64
}

function main
{
	rename_vg
	update_fstab_and_grub
	update_initramfs

	echo " "
	info "Reboot the server"
}

main
