#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-service_name=name
	-dbfs_user=name
	-dbfs_password=password
"

script_banner $ME $*

typeset	service_name=undef
typeset	dbfs_user=undef
typeset	dbfs_password=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-service_name=*)
			service_name=${1##*=}
			shift
			;;

		-dbfs_user=*)
			dbfs_user=${1##*=}
			shift
			;;

		-dbfs_password=*)
			dbfs_password=${1##*=}
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

exit_if_param_undef service_name	"$str_usage"
exit_if_param_undef dbfs_user		"$str_usage"
exit_if_param_undef dbfs_password	"$str_usage"

must_be_user root

typeset	ORACLE_HOME=undef
typeset	DBNAME=undef
IFS=':' read DBNAME ORACLE_HOME REM<<<"$(grep "^[A-Z].*line added by Agent" /etc/oratab)"

info "Configure DBFS for :"
info "ORACLE_HOME = '$ORACLE_HOME'"
info "DBNAME = '$DBNAME'"
info -n "Service $service_name running "
if grep -iqE "Service $service_name is running.*"<<<"$(srvctl status service -db $DBNAME)"
then
	info -f "$OK"
	LN
else
	info -f "$KO"
	LN
	info "$str_usage"
	LN
	exit 1
fi

info "Install fuse :"
exec_cmd yum -y install fuse fuse-libs
LN

line_separator
info "Make lib cache "
fake_exec_cmd cd /usr/local/lib
cd /usr/local/lib
if grep -qE "/usr/local/lib" /etc/ld.so.conf.d/usr_local_lib.conf
then
	info "/usr/local/lib already in /etc/ld.so.conf.d/usr_local_lib.conf"
else
	exec_cmd "echo '/usr/local/lib' >> /etc/ld.so.conf.d/usr_local_lib.conf"
fi
[ ! -h libclntsh.so.12.1 ] && \
			exec_cmd ln -s $ORACLE_HOME/lib/libclntsh.so.12.1 || true
[ ! -h libnnz12.so ] &&	\
			exec_cmd ln -s $ORACLE_HOME/lib/libnnz12.so || true
[ ! -h libclntshcore.so.12.1 ] &&	\
			exec_cmd ln -s $ORACLE_HOME/lib/libclntshcore.so.12.1 || true
[ ! -h libfuse.so ] &&	\
			exec_cmd ln -s /lib64/libfuse.so.2 libfuse.so || true
exec_cmd ldconfig
exec_cmd "ldconfig -p | grep -E 'fuse|12.1'"
LN

line_separator
info "Add oracle & grid to group fuse"
exec_cmd usermod -a -G fuse oracle
info "Add grid to group fuse"
exec_cmd usermod -a -G fuse grid
LN

line_separator
info "Setup dbfs_client"
#	A group named fuse must be created, with the user name that runs the dbfs_client as a member.
#	==> mettre oracle pas root ?? Sinon pourquoi positionner l'uid root ?
exec_cmd chown oracle.fuse $ORACLE_HOME/bin/dbfs_client
exec_cmd chmod u+rwxs,g+rx-w,o-rwx $ORACLE_HOME/bin/dbfs_client
exec_cmd ls -l $ORACLE_HOME/bin/dbfs_client
LN

line_separator
info "Create /sbin/mount.dbfs"
exec_cmd "rm -f /sbin/mount.dbfs"
exec_cmd "ln -s $ORACLE_HOME/bin/dbfs_client /sbin/mount.dbfs"
exec_cmd ls -l /sbin/mount.dbfs
LN

line_separator
info "Create mount point /mnt/dbfs"
fake_exec_cmd cd /mnt
cd /mnt
[ -d dbfs ] && exec_cmd "rmdir dbfs" || true
exec_cmd mkdir dbfs 
exec_cmd chown oracle.oinstall dbfs
exec_cmd ls -ld dbfs
LN

line_separator
info "Add mount point to fstab"
if grep -qE "mount.dbfs#$dbfs_user@$service_name" /etc/fstab
then
	info "Remove existing mount point"
	exec_cmd "sed -i '/#$dbfs_user@$service_name/d' /etc/fstab"
fi
exec_cmd "echo '/sbin/mount.dbfs#$dbfs_user@$service_name /mnt/dbfs fuse rw,user,noauto,default 0 0' >> /etc/fstab"
LN
