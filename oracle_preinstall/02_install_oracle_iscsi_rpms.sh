#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

line_separator
#	Il arrive que des fichiers soient vues comme corrompus, pour résoudre le
#	problème il suffit de démonter puis de remonter le répertoire.
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
info "Install Oracle rdbms rpm"
exec_cmd yum -y install $oracle_rdbms_rpm
LN

line_separator
info "Install iscsi packages"
exec_cmd yum -y install iscsi-initiator-utils
LN

line_separator
info "Install git"
exec_cmd yum -y install git
LN

line_separator
info "Install rlwrap"
exec_cmd yum -y install ~/plescripts/rpm/rlwrap-0.42-1.el7.x86_64.rpm
LN
