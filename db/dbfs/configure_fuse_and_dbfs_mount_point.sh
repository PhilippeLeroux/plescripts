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
	-db=name
	-pdb=name
	-service=auto	auto or service name.
"

script_banner $ME $*

typeset	db=undef
typeset	pdb=undef
typeset	service=undef
typeset	local_only=no

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
			shift
			;;

		-service=*)
			service=$(to_lower ${1##*=})
			shift
			;;

		-local_only)
			# Le script ne sera pas exécuté sur les autres serveurs.
			local_only=yes
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

must_be_user root

exit_if_param_undef db		"$str_usage"
exit_if_param_undef pdb		"$str_usage"

[ "$service" == auto ] && service=$(make_oci_service_name_for $pdb) || true

typeset	-r	dbfs_cfg_file=/home/oracle/${pdb}_dbfs.cfg

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
IFS=':' read dbn ORACLE_HOME REM<<<"$(grep "^[A-Z].*line added by Agent"	\
															/etc/oratab)"

info "ORACLE_HOME = '$ORACLE_HOME'"
exit_if_service_not_exists $db $service

line_separator
info "Install fuse :"
exec_cmd yum -y -q install fuse fuse-libs
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
#info "Add grid to group fuse"
#exec_cmd usermod -a -G fuse grid
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
info "Create mount point /mnt/$pdb"
fake_exec_cmd cd /mnt
cd /mnt
[ -d $pdb ] && exec_cmd "rmdir $pdb" || true
exec_cmd mkdir $pdb
exec_cmd chown oracle.oinstall $pdb
exec_cmd ls -ld $pdb
LN

line_separator
info "Configure fuse : oracle can mount and rw."
exec_cmd "sed -i '/user_allow_other/d' /etc/fuse.conf"
exec_cmd "echo 'user_allow_other' >> /etc/fuse.conf"
LN

line_separator
info "Add mount point to fstab"
if grep -qE "mount.dbfs.*$dbfs_user@$service" /etc/fstab
then
	info "Remove existing mount point"
	exec_cmd "sed -i '/@$service/d' /etc/fstab"
	LN
fi

if [ $wallet == yes ]
then
	exec_cmd "echo '/sbin/mount.dbfs#/@$service /mnt/$pdb fuse wallet,rw,user,allow_other,direct_io,noauto,default 0 0' >> /etc/fstab"
else
	exec_cmd "echo '/sbin/mount.dbfs#$dbfs_user@$service /mnt/$pdb fuse rw,user,allow_other,direct_io,noauto,default 0 0' >> /etc/fstab"
fi
LN

if [[ $gi_count_nodes -gt 1 && $local_only == no ]]
then
	line_separator
	execute_on_other_nodes ". .bash_profile; ~/plescripts/db/dbfs/${ME##*/}	\
								-db=$db -pdb=$pdb -local_only"
	LN
fi

line_separator
if grep -qE "oracle" <<<"$(who)"
then
	warning "***********************************"
	warning "YOU must disconnect oracle account."
	warning "***********************************"
	exec_cmd w oracle
	LN
fi

if [ $local_only == no ]
then # Affiche l'info que sur le serveur ou a été lancé le script.
	add_dynamic_cmd_param "\"plescripts/db/dbfs/create_crs_resource_for_dbfs.sh"
	add_dynamic_cmd_param "-db=$db -pdb=$pdb -service=$service\""
	exec_dynamic_cmd "su - grid -c"
fi
