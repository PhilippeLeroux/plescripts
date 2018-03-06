#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/gilib.sh
. ~/plescripts/networklib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset	-r	ME=$0
typeset	-r	PARAMS="$*"

#	Note :
#	Le rafraîchissement d'un PDB ne me semble pas très util en 12cR2, mais avec
#	la 18cR1 il est possible d'effectuer des switchover entre PDB, donc à voir.
#
#	Sur un PDB en refresh, les alias TNS et les services ne sont pas crée, si
#	le CRS est utilisé il ouvrira le PDB au démarrage, il n'est pas possible
#	d'enregistrer le paramètre -startoption.

typeset		db=undef
typeset		pdb=undef
typeset		remote_host=undef
typeset		remote_pdb=undef
typeset		remote_srv=none
typeset		admin_user=pdbadmin
typeset		admin_pass=$oracle_password
typeset		wallet=${WALLET:-$(enable_wallet 12.2)}

typeset	-i	refresh_mn=-1	# -1 no refresh, 0 refresh manual

add_usage "-db=name"					"DB name."
add_usage "-pdb=name"					"Local PDB name."
add_usage "-remote_host=name"			"Remote host name."
add_usage "-remote_pdb=name"			"Remote PDB name."
add_usage "[-remote_srv=name]"			"Service name for remote PDB, default is remote 'pdb name' + '_oci'."
add_usage "[-refresh_mn=#]"				"Refresh frequency, or manual."
add_usage "[-wallet=$wallet]"			"yes|no yes : Use Wallet Manager for pdb connection."
add_usage "[-admin_user=$admin_user]"
add_usage "[-admin_pass=$admin_pass]"

typeset	-r	str_usage=\
"Usage :
$ME
$(print_usage)

Work only for 12.2 and above.

Dataguard not tested.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-pdb=*)
			pdb=${1##*=}
			shift
			;;

		-remote_host=*)
			remote_host=${1##*=}
			shift
			;;

		-remote_pdb=*)
			remote_pdb=${1##*=}
			shift
			;;

		-remote_srv=*)
			remote_srv=${1##*=}
			shift
			;;

		-refresh_mn=*)
			val=$(to_lower ${1##*=})
			[ "$val" == manual ] && refresh_mn=0 || refresh_mn=$val
			unset val
			shift
			;;

		-wallet=*)
			wallet=$(to_lower ${1##*=})
			shift
			;;

		-admin_user=*)
			admin_user=${1##*=}
			shift
			;;

		-admin_pass=*)
			admin_pass=${1##*=}
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

#	$1	dblink name
function sql_test_dblink
{
	set_sql_cmd "whenever sqlerror exit 1;"
	set_sql_cmd "select 1 from dual@$1;"
}

function sql_create_pdb
{
	typeset		ddl_create="create pluggable database $pdb from $remote_pdb@$dblink_name"
	case $refresh_mn in
		-1)
			:	# No refresh
			;;
		0)
			ddl_create="$ddl_create refresh mode manual"
			;;
		*)
			ddl_create="$ddl_create refresh mode every $refresh_mn minutes"
			;;
	esac
	set_sql_cmd "whenever sqlerror exit 1;"
	set_sql_cmd "$ddl_create;"
	if [ $refresh_mn == -1 ]
	then
		set_sql_cmd "alter pluggable database $pdb open instances=all;"
		set_sql_cmd "alter pluggable database $pdb save state;"
	fi
}

# Si un PDB est clonée depuis un PDB existant, il faut supprimer tous les
# services du pdb existant qui sont dans le PDB cloné.
function sql_remove_services_from_cloned_pdb
{
	set_sql_cmd "alter session set container=$pdb;"
	echo "set serveroutput on"
	echo "begin"
	echo "    for s in ( select name from all_services where name != '$(to_lower $pdb)' )"
	echo "    loop"
	echo "        dbms_output.put_line( 'Stop and remove service : '||s.name );"
	echo "        dbms_service.stop_service( s.name );"
	echo "        dbms_service.delete_service( s.name );"
	echo "    end loop;"
	echo "end;"
	echo "/"
}

function create_wallet
{
	line_separator
	exec_cmd "~/plescripts/db/add_sysdba_credential_for_pdb.sh -db=$db -pdb=$pdb"
}

ple_enable_log -params $PARAMS

exit_if_param_undef db			"$str_usage"
exit_if_param_undef pdb			"$str_usage"
exit_if_param_undef remote_host	"$str_usage"
exit_if_param_undef remote_pdb	"$str_usage"

exit_if_param_invalid	wallet	"yes no"	"$str_usage"

must_be_user oracle

exit_if_ORACLE_SID_not_defined

[ $remote_srv == none ] && remote_srv=${remote_pdb}_oci || true

if [[ $(read_orcl_release) == 12.1 ]]
then
	error "Work only for 12.2 and above."
	LN
fi

info -n "ping $remote_host "
if ! ping_test $remote_host
then
	info -f "[$KO]"
	LN
	exit 1
else
	info -f "[$OK]"
	LN
fi

typeset	-r	tnsalias=${remote_host}_${remote_srv}
typeset	-r	dblink_name=${remote_host}_${remote_srv}

info "Create TNS alias $tnsalias"
exec_cmd "~/plescripts/db/add_tns_alias.sh			\
							-service=$remote_srv	\
							-host_name=$remote_host	\
							-tnsalias=$tnsalias"

info -n "tnsping $tnsalias "
if ! tnsping $tnsalias >/dev/null 2>&1
then
	info -f "[$KO]"
	LN
	exit 1
else
	info -f "[$OK]"
	LN
fi

info "Create database link $dblink_name"
sqlplus_cmd "$(set_sql_cmd "create database link $dblink_name connect to $admin_user identified by $admin_pass using '$tnsalias';")"
LN

info "Test database link $dblink_name"
sqlplus_cmd "$(sql_test_dblink $dblink_name)"
if [ $? -ne 0 ]
then
	error "Failed."
	LN
	exit 1
fi
LN

info "Create PDB $pdb from PDB ${remote_pdb}@${remote_host}."
sqlplus_cmd "$(sql_create_pdb)"
if [ $? -ne 0 ]
then
	error "Failed."
	LN
	exit 1
fi
LN

line_separator
case $refresh_mn in
	-1)	# No refresh
		info "Remove cloned services."
		sqlplus_cmd "$(sql_remove_services_from_cloned_pdb)"
		LN

		info "Delete alias used for cloning."
		exec_cmd "~/plescripts/db/delete_tns_alias.sh -tnsalias=$tnsalias"
		LN

		info "Drop database link used for cloning."
		sqlplus_cmd "$(set_sql_cmd "drop database link $dblink_name;")"
		LN

		exec_cmd "~/plescripts/db/create_srv_for_single_db.sh -db=$db -pdb=$pdb"
		LN

		if [ $wallet == no ]
		then
			exec_cmd ~/plescripts/db/add_tns_alias.sh					\
											-tnsalias=sys${pdb}			\
											-service=$service			\
											-host_name=$(hostname -s)
		else
			create_wallet
		fi

		info "Services registered."
		exec_cmd "lsnrctl status | grep -E '^Serv.*$pdb.*'"
		LN
		;;

	*)	# refresh, nothing todo.
		sqlplus_cmd "$(set_sql_cmd @lspdbs)"
		LN
		;;
esac

