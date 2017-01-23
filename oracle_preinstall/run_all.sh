#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r db_type=$1

fake_exec_cmd cd ~/plescripts/oracle_preinstall
cd ~/plescripts/oracle_preinstall

#	Le problème de lecture du point de montage NFS est revenu.
info "Workaround yum repository errors :"
exec_cmd "umount /mnt$infra_olinux_repository_path"
timing 5
exec_cmd "mount /mnt$infra_olinux_repository_path"
timing 5
LN
exec_cmd "~/plescripts/yum/clean_cache.sh"
LN

exec_cmd "./01_create_oracle_users.sh -release=$oracle_release -db_type=$db_type"
LN

exec_cmd "./02_install_some_rpms.sh"
LN

if [ $db_type != single_fs ]
then
	exec_cmd "./03_install_oracleasm.sh"
	LN
fi

exec_cmd "./04_apply_os_prerequis.sh -db_type=$db_type"
LN

exit
