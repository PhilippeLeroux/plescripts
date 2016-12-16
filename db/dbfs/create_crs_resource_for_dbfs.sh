#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME ...."

script_banner $ME $*

typeset		pdb_name=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb_name=*)
			pdb_name=${1##*=}
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

exit_if_param_undef pdb_name	"$str_usage"

must_be_user grid

typeset	-r	db_name=$(sed "s/\([a-z]*\)[0-9]*/\1/" <<<$pdb_name)
typeset	-r	service_name=pdb${pdb_name}_oci
typeset	-r	nr_server=$(sed "s/.*\([0-9].*\)$/\1/" <<<"$(hostname -s)")
typeset	-r	resource_name=$(printf "srv%02d.pdb%s.dbfs" $nr_server $pdb_name)
typeset	-r	dbfs_name=staging_area

info "Database $db_name, pdb $pdb_name : create resource $resource_name"
info -n "Service $service_name running "
if grep -iqE "Service $service_name is running.*"<<<"$(srvctl status service -db $db_name)"
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

typeset -r ora_service="ora.${db_name}.${service_name}.svc"

add_dynamic_cmd_param "-type generic_application"
add_dynamic_cmd_param "-attr \"START_PROGRAM='/usr/bin/sudo -iu oracle plescripts/db/dbfs/automount_dbfs.sh $pdb_name'"
add_dynamic_cmd_param "    ,STOP_PROGRAM='/usr/bin/sudo -iu oracle fusermount -u /mnt/$pdb_name'"
add_dynamic_cmd_param "    ,CLEAN_PROGRAM='/usr/bin/sudo -iu oracle fusermount -u -z /mnt/$pdb_name'"
add_dynamic_cmd_param "    ,CHECK_PROGRAMS='/usr/bin/sudo -iu oracle ls -ld /mnt/$pdb_name/$dbfs_name'"
add_dynamic_cmd_param "    ,HOSTING_MEMBERS=$(hostname -s)"
add_dynamic_cmd_param "    ,PLACEMENT=restricted"
add_dynamic_cmd_param "    ,START_DEPENDENCIES=hard($ora_service)"
add_dynamic_cmd_param "    ,STOP_DEPENDENCIES=hard($ora_service)\""
exec_dynamic_cmd "crsctl add resource $resource_name"
LN

info "Status"
exec_cmd crsctl stat res $resource_name -t
LN

info "Start $resource_name"
exec_cmd crsctl start res $resource_name
LN

info "Status"
exec_cmd crsctl stat res $resource_name -t
LN
exit 0
#,LD_LIBRARY_PATH='$ORACLE_HOME/lib:$ORACLE_HOME/rdbms/lib'	\
#,TNS_ADMIN='$TNS_ADMIN'										\

exec_cmd -c crsctl delete resource srv01.pdbdaisy01.dbfs -f
LN


#exec_cmd -c crsctl delete serverpool dbfsPool 
#exec_cmd crsctl add serverpool dbfsPool -attr "SERVER_NAMES='srvdaisy01 srvdaisy02'"
#LN

#	https://docs.oracle.com/cd/B28359_01/rac.111/b28255/crschp.htm#CWADD600
#	PLACEMENT = balanced | favored | restricted
set -x
crsctl add resource srv01.pdbdaisy01.dbfs							\
	-type generic_application										\
	-attr "START_PROGRAM='/sbin/mount.dbfs /mnt/dbfs'				\
		,STOP_PROGRAM='/bin/fusermount -u /mnt/dbfs'				\
		,CLEAN_PROGRAM='/bin/fusermount -u -z /mnt/dbfs'			\
		,CHECK_PROGRAMS='/usr/bin/ls /mnt/dbfs'						\
		,HOSTING_MEMBERS=srvdaisy01									\
		,PLACEMENT=restricted										\
		,CARDINALITY=1												\
		,START_DEPENDENCIES=hard(ora.daisy.pdbdaisy01_oci.svc)	\
		,STOP_DEPENDENCIES=hard(ora.daisy.pdbdaisy01_oci.svc)"
[ $? -ne 0 ] && exit 1
set +x
#-type cluster_resource											\
#	,SERVER_POOLS=dbfsPool										\
#	-attr "START_PROGRAM='/sbin/mount /mnt/dbfs'					\
#		,STOP_PROGRAM='/bin/fusermount -u /mnt/dbfs'				\
#		,SERVER_POOLS=dbfsPool								\
#		,PLACEMENT=favored	\
#		,CARDINALITY=2												\
#		,START_DEPENDENCIES='hard(ora.daisy.pdbdaisy01_oci.svc)'	\
#		,STOP_DEPENDENCIES='hard(ora.daisy.pdbdaisy01_oci.svc)'"	

#,ENVIRONMENT_VARS='ORACLE_HOME=$ORACLE_HOME'				\
#,CLEAN_PROGRAM='/bin/fusermount -u -z /mnt/dbfs'			\
#,CHECK_PROGRAMS='ls /mnt/dbfs'								\
#	-serverPoolName poolAllNodes
		#,SERVER_POOLS=poolAllNodes								\
		#,HOSTING_MEMBERS='srvdaisy01 srvdaisy02'	\
LN

exec_cmd crsctl stat res -t
LN

exec_cmd crsctl start resource srv01.pdbdaisy01.dbfs
LN
