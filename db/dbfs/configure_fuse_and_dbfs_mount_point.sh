#!/bin/bash
# vim: ts=4:sw=4

PLELIB_OUTPUT=FILE
. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
	-service_name=name
"

script_banner $ME $*

typeset	service_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-service_name=*)
			service_name=$(to_lower ${1##*=})
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

must_be_user root

typeset	-r	pdb_name=$(sed 's/pdb\(.*\)_oci/\1/'<<<$service_name)
typeset	-r	dbfs_cfg_file=/home/oracle/${pdb_name}_dbfs.cfg

line_separator
info "Load $dbfs_cfg_file"
if [ ! -f $dbfs_cfg_file ]
then
	error "File not exists."
	LN
	exit 1
fi
. $dbfs_cfg_file
LN

line_separator
typeset	ORACLE_HOME=undef
IFS=':' read dbn ORACLE_HOME REM<<<"$(grep "^[A-Z].*line added by Agent" /etc/oratab)"

info "ORACLE_HOME = '$ORACLE_HOME'"
typeset DBNAME=$(extract_db_name_from $pdb_name)
exit_if_service_not_running $DBNAME $pdb_name $service_name

line_separator
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

typeset	-r	rel=$(cut -d. -f1-2<<<"$oracle_release")
typeset	-r	ver=$(cut -d. -f1<<<"$oracle_release")

[ ! -h libclntsh.so.$rel ] && \
			exec_cmd ln -s $ORACLE_HOME/lib/libclntsh.so.$rel || true
[ ! -h libnnz$ver.so ] &&	\
			exec_cmd ln -s $ORACLE_HOME/lib/libnnz$ver.so || true
[ ! -h libclntshcore.so.$rel ] &&	\
			exec_cmd ln -s $ORACLE_HOME/lib/libclntshcore.so.$rel || true
[ ! -h libfuse.so ] &&	\
			exec_cmd ln -s /lib64/libfuse.so.2 libfuse.so || true
exec_cmd ldconfig
exec_cmd "ldconfig -p | grep -E 'fuse|$rel'"
LN

line_separator
info "Add oracle to group fuse"
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
info "Create mount point /mnt/$pdb_name"
fake_exec_cmd cd /mnt
cd /mnt
[ -d $pdb_name ] && exec_cmd "rmdir $pdb_name" || true
exec_cmd mkdir $pdb_name 
exec_cmd chown oracle.oinstall $pdb_name
exec_cmd ls -ld $pdb_name
LN

line_separator
info "Configure fuse : grid & oracle can mount and rw."
exec_cmd "sed -i '/user_allow_other/d' /etc/fuse.conf"
exec_cmd "echo 'user_allow_other' >> /etc/fuse.conf"
LN

line_separator
info "Add mount point to fstab"
if grep -qE "mount.dbfs#$dbfs_user@$service_name" /etc/fstab
then
	info "Remove existing mount point"
	exec_cmd "sed -i '/#.*@$service_name/d' /etc/fstab"
	LN
fi

if [ $wallet == yes ]
then
	exec_cmd "echo '/sbin/mount.dbfs#/@$service_name /mnt/$pdb_name fuse wallet,rw,user,allow_other,direct_io,noauto,default 0 0' >> /etc/fstab"
else
	exec_cmd "echo '/sbin/mount.dbfs#$dbfs_user@$service_name /mnt/$pdb_name fuse rw,user,allow_other,direct_io,noauto,default 0 0' >> /etc/fstab"
fi
LN

line_separator
if grep -qE "oracle" <<<"$(who)"
then
	warning "***********************************"
	warning "YOU must disconnect oracle account."
	warning "***********************************"
	LN
fi

if grep -qE "grid" <<<"$(who)"
then
	warning "*********************************"
	warning "YOU must disconnect grid account."
	warning "*********************************"
	LN
fi

if [ $gi_count_nodes -gt 1 ]
then
	info "Run this script on servers : $gi_node_list"
	LN
fi

info "With user grid execute :"
info "cd plescripts/db/dbfs/"
info "./create_crs_resource_for_dbfs.sh -pdb_name=$pdb_name"
LN
