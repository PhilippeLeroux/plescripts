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
#
#	RMAN :
#	Si les archivelogs de la base source sont effacées alors le PDB ne pourra
#	plus être mis à jour, je n'ai pas trouvé de close de type 'configure archivelog
#	deletion policy to applied on all standby;' et cette clause n'a aucun effet.

typeset	-r	orcl_release="$(read_orcl_release)"

typeset		db=undef
typeset		pdb=undef
typeset		remote_host=undef
typeset		remote_db=undef
typeset		remote_pdb=none
typeset		admin_user=pdbadmin
typeset		admin_pass=$oracle_password
typeset		wallet=${WALLET:-$(enable_wallet $orcl_release)}
typeset	-r	hostname=$(hostname -s)

typeset	-i	refresh_mn=-1	# -1 no refresh, 0 refresh manual

add_usage "-db=name"					"DB name."
add_usage "-pdb=name"					"Local PDB name."
add_usage "-remote_host=name"			"Remote host name."
case $orcl_release in
	12*)
		:
		;;
	*)
		add_usage "-remote_db=name"	"Only for 18c and above."
		;;
esac
add_usage "[-remote_pdb=name]"			"Remote PDB name. If missing use -pdb parameter."
add_usage "[-refresh_mn=#]"				"Refresh frequency, or manual."
add_usage "[-wallet=$wallet]"			"yes|no yes : Use Wallet Manager for pdb connection."
add_usage "[-admin_user=$admin_user]"

add_usage "[-admin_pass=$admin_pass]"

typeset	-r	str_usage=\
"Usage :
$ME
$(print_usage)

Work only for 12.2 and above.

NOTE :
    Tous les droits sont donnés pour que le switchover entre PDB puisse être
    effectué, mais le script pdb_switchover.sh échoue.

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
			db=$(to_lower ${1##*=} )
			shift
			;;

		-pdb=*)
			pdb=$(to_lower ${1##*=})
			shift
			;;

		-remote_host=*)
			remote_host=${1##*=}
			shift
			;;

		-remote_db=*)
			remote_db=$(to_lower ${1##*=})
			shift
			;;

		-remote_pdb=*)
			remote_pdb=$(to_lower ${1##*=})
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

# Print to stdout all ddl statements to create PDB $pdb.
function ddl_clone_pdb
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
#
# Print to stdout all ddl statements to remove all services for PDB $pdb
function ddl_remove_services_from_cloned_pdb
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

# $1 pdb name
# return 0 if pdb exists, else 1.
function pdb_exists
{
	typeset	-r	sql_query="select name from gv\$containers;"
	sqlplus_exec_query "$sql_query" | grep $1
}

# Create user c##u1 on 2 databases.
function create_common_users
{
	function ddl_create_local_common_user
	{
		set_sql_cmd "create user $common_user identified by $oracle_password;"
		set_sql_cmd "grant create session, resource, create any table, unlimited tablespace to $common_user container=all;"
		set_sql_cmd "grant create pluggable database to $common_user container=all;"
		set_sql_cmd "grant sysoper to $common_user container=all;"
	}

	typeset	-r remote_connstr="sys/$oracle_password@$remote_db as sysdba"
	if ! db_username_exists "$remote_connstr" $common_user 
	then
		line_separator
		info "Create and grant privilege to $common_user on $remote_db"
		sqlplus_cmd_with $remote_connstr "$(ddl_create_local_common_user)"
		LN
	fi

	if ! db_username_exists "sys/$oracle_password as sysdba" $common_user
	then
		line_separator
		info "Create and grant privilege to $common_user on $db"
		sqlplus_cmd "$(ddl_create_local_common_user)"
		LN
	fi
}

ple_enable_log -params $PARAMS

exit_if_param_undef db			"$str_usage"
exit_if_param_undef pdb			"$str_usage"
exit_if_param_undef remote_host	"$str_usage"
exit_if_param_undef remote_db	"$str_usage"

exit_if_param_invalid	wallet	"yes no"	"$str_usage"

must_be_user oracle

exit_if_ORACLE_SID_not_defined

# L'utilisateur est crée sur les 2 bases.
typeset	-r	common_user="c##u1"
typeset	-r	dblink_name=cdb_$remote_db
typeset	-r	tnsalias=$remote_db

[ $remote_pdb == none ] && remote_pdb=$pdb || true

if pdb_exists $pdb
then
	error "PDB $pdb exists on server $HOSTNAME."
	LN
	exit 1
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

case $orcl_release in
	12.1)
		error "Refresh PDB not implemented for $orcl_release"
		LN
		exit 1
		;;

	12.2)
		warning "not tested."
		LN
		;;

	18.0)
		: # OK
		;;

	*)
		warning "not tested."
		LN
		;;
esac

line_separator
# En 12cR2 l'alias était crée avec le service du PDB.
# En 18c c'est le service du CDB qui est utilisé.
info "Add tns alias for $remote_db on $hostname (for sqlplus connection & db link $dblink_name)"
exec_cmd "~/plescripts/db/add_tns_alias.sh			\
							-service=$remote_db		\
							-host_name=$remote_host	\
							-tnsalias=$tnsalias"

exit_if_tnsping_failed $tnsalias

create_common_users

if ! dblink_exists $dblink_name
then
	line_separator
	info "Create database link $dblink_name (For cloning and refresh PDB)"
	sqlplus_cmd "$(ddl_create_dblink $dblink_name $common_user $admin_pass $tnsalias)"
	LN
fi

exit_if_test_dblink_failed $dblink_name

line_separator
info "Create PDB $db[$pdb] from PDB $remote_db[$remote_pdb]."
sqlplus_cmd "$(ddl_clone_pdb)"
if [ $? -ne 0 ]
then
	error "Failed."
	LN
	exit 1
fi
LN

case $refresh_mn in
	-1)	# No refresh
		line_separator
		info "Remove cloned services."
		sqlplus_cmd "$(ddl_remove_services_from_cloned_pdb)"
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
			exec_cmd ~/plescripts/db/add_tns_alias.sh				\
											-tnsalias=sys${pdb}		\
											-service=$pdb			\
											-host_name=${hostname}
		else
			create_wallet
		fi

		info "Services registered."
		exec_cmd "lsnrctl status | grep -Ei '^Serv.*$pdb.*'"
		LN
		;;
esac

line_separator
sqlplus_cmd "$(set_sql_cmd @lspdbs)"
LN
