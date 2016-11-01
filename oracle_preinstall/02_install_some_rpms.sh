#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

line_separator
#	Il arrive que des fichiers soient vues comme corrompus, pour tenter de résoudre
#	le problème démontage/montage du dépôt yum.
#	L'origine du pb ??
info "NFS problem workaround"
exec_cmd umount /mnt$infra_olinux_repository_path
timing 1
output=$(ls -1qA /mnt$infra_olinux_repository_path)
if [ x"$output" != x ]
then	# Le répertoire n'est pas vide donc umount a échoué.
	error "Cannot umount '/mnt$infra_olinux_repository_path'"
	exit 1
fi
exec_cmd mount /mnt$infra_olinux_repository_path
timing 1

line_separator
exec_cmd yum -y install	iscsi-initiator-utils	\
						git						\
						$oracle_rdbms_rpm		\
						~/plescripts/rpm/rlwrap-0.42-1.el7.x86_64.rpm
LN
