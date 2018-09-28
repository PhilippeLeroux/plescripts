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
typeset		remote_host=none
typeset		remote_db=undef
typeset		remote_pdb=none
typeset		common_user_pass=$oracle_password
typeset		wallet=${WALLET:-$(enable_wallet $orcl_release)}
typeset	-r	hostname=$(hostname -s)

typeset	-i	refresh_mn=666	# -1 no refresh, 0 refresh manual

add_usage "-db=name"					"DB name."
add_usage "-pdb=name"					"Local PDB name."
add_usage "-remote_db=name"				"remote db name."
add_usage "-refresh_mn=#"				"Refresh frequency, manual or clone."
add_usage "[-remote_host=name]"			"Remote host name, if missing use srv\${remote_db}01"
add_usage "[-remote_pdb=name]"			"Remote PDB name. If missing use -pdb parameter."
add_usage "[-wallet=$wallet]"			"yes|no yes : Use Wallet Manager for pdb connection."
add_usage "[-common_user_pass=$common_user_pass]"

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
			case "$val" in
				manual)
					refresh_mn=0
					;;
				clone)
					refresh_mn=-1
					;;
				*)
					refresh_mn=$val
			esac
			unset val
			shift
			;;

		-wallet=*)
			wallet=$(to_lower ${1##*=})
			shift
			;;

		-common_user_pass=*)
			common_user_pass=${1##*=}
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
# $1 pdb name
# $2 name of remote pdb
#
# Print to stdout all ddl statements to delete all services for PDB $pdb
function ddl_delete_services_from_cloned_pdb
{
	# Quand le CRS n'est pas utilisé les services sont parfois démarrés.
	set_sql_cmd "alter session set container=$1;"
	set_sql_prompt
	echo "set serveroutput on"
	echo "begin"
	echo "    for s in ( select name from all_services where name like '${2}_%' )"
	echo "    loop"
	echo "        begin"
	echo "            dbms_output.put_line( 'Stop service : '||s.name );"
	echo "            dbms_service.stop_service( s.name );"
	echo "        exception"
	echo "            when others then null;"
	echo "        end;"
	echo "        dbms_output.put_line( 'Delete service : '||s.name );"
	echo "        dbms_service.delete_service( s.name );"
	echo "        dbms_output.put_line( '.' );"
	echo "    end loop;"
	echo "end;"
	echo "/"
}

function create_wallet
{
	line_separator
	exec_cmd "~/plescripts/db/add_sysdba_credential_for_pdb.sh -db=$db -pdb=$pdb"
}

# Create user c##u1 on 2 databases.
function create_common_users_on_2_databases
{
	function ddl_create_local_common_user
	{
		set_sql_cmd "create user $common_user identified by $common_user_pass;"
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
exit_if_param_undef remote_db	"$str_usage"

if [ $refresh_mn -eq 666 ]
then
	error "refresh_mn not defined."
	LN

	info "$str_usage"
	LN

	exit 1
fi

exit_if_param_invalid	wallet	"yes no"	"$str_usage"

must_be_user oracle

exit_if_ORACLE_SID_not_defined

# L'utilisateur est crée sur les 2 bases.
typeset	-r	common_user="c##u1"
typeset	-r	dblink_name=cdb_$remote_db
typeset	-r	tnsalias=$remote_db

[ $remote_host == none ] && remote_host=srv${remote_db}01 || true
[ $remote_pdb == none ] && remote_pdb=$pdb || true

if pdb_exists $pdb
then
	error "PDB $pdb exists on database $db."
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

	12.2|18.0)
		: # OK
		;;

	*)
		warning "not tested."
		LN
		;;
esac

line_separator
info "Add tns alias for $remote_db on $hostname (for sqlplus connection & db link $dblink_name)"
exec_cmd "~/plescripts/db/add_tns_alias.sh			\
							-service=$remote_db		\
							-host_name=$remote_host	\
							-tnsalias=$tnsalias"

exit_if_tnsping_failed $tnsalias

create_common_users_on_2_databases

if ! dblink_exists $dblink_name
then
	line_separator
	info "Create database link $dblink_name (For cloning and refresh PDB)"
	sqlplus_cmd "$(ddl_create_dblink $dblink_name $common_user $common_user_pass $tnsalias)"
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

		# Même si le CRS n'est pas utilisé et que les PDB ont le même nom, ils
		# sont détruit puis recrée. Lors de la création des services les alias
		# TNS seront crées.
		line_separator
		info "Delete cloned services like ${remote_pdb}_%."
		sqlplus_cmd "$(ddl_delete_services_from_cloned_pdb $pdb $remote_pdb)"
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

		line_separator
		info "Services registered."
		exec_cmd "lsnrctl status | grep -Ei '^Serv.*$pdb.*'"
		LN
		;;

	*)
		line_separator
		warning "Services ${remote_pdb}% exists, but cannot be deleted."
		LN
		;;
esac

line_separator
sqlplus_cmd "$(set_sql_cmd @lspdbs)"
LN
