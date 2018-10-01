# vim: ts=4:sw=4

if [ x"$plelib_banner" == x ]
then
	echo "inclure plelib avant dblib"
	exit 1
fi

. ~/plescripts/global.cfg

typeset -r	SQL_PROMPT="prompt SQL>"

#*> Si PLELIB_OUTPUT == FILE alors sqlplus log sa sortie dans $PLELIB_LOG_FILE
#*> Initialise la variable SPOOL
function sqlplus_init_spool
{
	#	La variable SPOOL permet de loger la sortie de sqplus.
	if [ "$PLELIB_OUTPUT" == FILE ]
	then
		SPOOL="spool $PLELIB_LOG_FILE append\n"
	else
		SPOOL=""
	fi
}

#*>	Call oraenv with ORACLE_SID=$1
function load_oraenv_for
{
	ORACLE_SID=$(to_upper $1)
	info "Load oracle environment for $ORACLE_SID"
	ORAENV_ASK=NO . oraenv -s
	LN
}

#*> $1 database name
#*> exit 1 if $1 not exists.
function exit_if_database_not_exists
{
	if command_exists crsctl
	then
		srvctl status database -db $1 >/dev/null 2>&1
		typeset ret=$?
	else
		ps -ef|grep -q [p]mon_$(to_upper $1)
		typeset ret=$?
	fi
	if [ $ret -ne 0 ]
	then
		error "Database $1 not exists."
		LN
		exit 1
	fi
}

#*> if variable ORACLE_SID not defined : exit 1
function exit_if_ORACLE_SID_not_defined
{
	if [[ x"$ORACLE_SID" == x || "$ORACLE_SID" == NOSID ]]
	then
		error "$(hostname -s) : ORACLE_SID not define."
		LN
		exit 1
	fi
}

#*> print yes to stdout if dataguarg configutation available, else no.
function dataguard_config_available
{
	dgmgrl -silent sys/$oracle_password 'show configuration' >/dev/null 2>&1
	[ $? -eq 0 ] && echo "yes" || echo "no"
}

#*> $1 database name
#*> print to stdout database role : primary or physical
function read_database_role
{
	typeset -r dbn=$(to_lower $1)
	to_lower $(dgmgrl -silent sys/Oracle12 'show configuration'	|\
							grep $dbn | cut -d- -f2 | awk '{ print $1 }')
}

#*> arrays physical_list & stby_server_list must be declared
function load_stby_database
{
	typeset name
	while read name
	do
		physical_list+=( $name )
	done<<<"$(dgmgrl sys/$oracle_password 'show configuration'	|\
					grep "Physical standby" | awk '{ print $1 }')"

	typeset stby_name
	for stby_name in ${physical_list[*]}
	do
		stby_server_list+=($(tnsping $stby_name | tail -2 | head -1 |\
					sed "s/.*(\s\?HOST\s\?=\s\?\(.*\)\s\?)\s\?(\s\?PORT.*/\1/"))
	done

}

#*> $1 standby name
#*> return 0 if stby is disabled, else return 1
function stby_is_disabled
{
	dgmgrl sys/$oracle_password 'show configuration'|grep -i "$1" | grep -q "(disabled)"
}

#*> print to stdout primary database name
function read_primary_name
{
	dgmgrl sys/$oracle_password 'show configuration'	|\
				grep "Primary database" | awk '{ print $1 }'
}

#*> Utilisé avec sqlplus_cmd permet d'afficher un prompt avec le message "$@"
#*> Voir set_sql_cmd pour un exemple.
function set_sql_prompt
{
	cat<<-WT
	prompt
	prompt $@
	WT
}

#*>	$@ contient une commande à exécuter.
#*>	La fonction n'exécute pas la commande elle :
#*>		- affiche le prompt SQL> suivi de la commande.
#*>		- affiche sur la seconde ligne la commande.
#*>
#*> Utilisé avec les fonctions sqlplus_cmd[_with]
#*>
#*> Ex 1 : sqlplus_cmd "$(set_sql_cmd "alter database open;")"
#*>
#*> Ex 2 :
#*>		function open_pdb # $1 pdb name
#*>		{
#*>			set_sql_prompt "Open PDB $1"
#*>			set_sql_cmd "alter session set container=$1;"
#*>			set_sql_cmd "alter pluggable database open;"
#*>		}
#*>		sqlplus_cmd "$(open_pdb pdb01)"
function set_sql_cmd
{
cat<<WT
prompt
$SQL_PROMPT $@;
$@
WT
}

#*> $1 chaine de connection
#*>	Exécute les commandes "$@" avec sqlplus
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_cmd_with
{
	typeset connect_string="$1"
	shift
	if [ "$1" == as ]
	then
		typeset -r connect_string="$connect_string as $2"
		shift 2
	fi

	sqlplus_init_spool

	typeset	-r	db_cmd="$*"
	fake_exec_cmd sqlplus -s "$connect_string"
	if [ $? -eq 0 ]
	then
		echo -e "${SPOOL}set timin on\n$db_cmd\n" | \
			sqlplus -s $connect_string
		return $?
	else
		echo -e "${SPOOL}set timin on\n$db_cmd\n"
		return 1
	fi
}

#*>	Exécute les commandes "$@" avec sqlplus en sysdba
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_cmd
{
	sqlplus_cmd_with "sys/$oracle_password as sysdba" "$@"
}


#*>	Exécute les commandes "$@" avec sqlplus en sysasm
#*>	Affichage correct sur la sortie std et la log.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function sqlplus_asm_cmd
{
	sqlplus_init_spool
	fake_exec_cmd sqlplus -s / as sysasm
	if [ $? -eq 0 ]
	then
		printf "${SPOOL}set echo off\nset timin on\n$@\n" | \
			sqlplus -s / as sysasm
		return 0
	else
		printf "${SPOOL}set echo off\nset timin on\n$@\n"
		return 1
	fi
}

#*> $1 connect string
#*> $2 sql query
#*>
#*>	Objectif de la fonction :
#*>	 Exécute une requête, seul son résultat est affiché, la sortie peut être 'parsée'
#*>	 Par exemple obtenir la liste de tous les PDBs d'un CDB.
#*>
#*>	N'inscrit rien dans la log.
function sqlplus_exec_query_with
{
	typeset	-r	string_connection="$1"
	typeset -r	seq_query="$(double_symbol_percent "$2")"
	printf "whenever sqlerror exit 1\nset term off echo off feed off heading off\n$seq_query" | \
		sqlplus -s "$string_connection"
}

#*> $1 sql query
#*>
#*> call sqlplus_exec_query_with "sys/$oracle_password as sysdba" "$1"
function sqlplus_exec_query
{
	sqlplus_exec_query_with	"sys/$oracle_password as sysdba" "$1"
}

#*> Affiche tous les PDB RW de l'instance $1
#*> Les bases en RO sont considérées comme des SEED.
#*> $1 instance name
function get_rw_pdbs
{
typeset	-r	l_sql_read_pdb_rw=\
"select
	c.name
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
where
	i.instance_name = '$(to_upper $1)'
and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT' )
and c.open_mode = 'READ WRITE';
"
	sqlplus_exec_query "$l_sql_read_pdb_rw"
}

#*> $1 database parameter
function orcl_parameter_value
{
typeset opv_query=\
"	select
		p.display_value
	from
		v\$parameter p
	where
		p.name = '$1'
	;
"
	sqlplus_exec_query "$opv_query" | xargs
}

#*>	Objectif de la fonction :
#*>	 Exécute une requête dont le but n'est que l'affichage d'un résultat.
#*>	Affiche la requête exécutée.
function sqlplus_print_query
{
	typeset -r	seq_query="$(double_symbol_percent "$1")"
	sqlplus_init_spool
	fake_exec_cmd "sqlplus -s sys/$oracle_password as sysdba"
	printf "${SPOOL}whenever sqlerror exit 1\n$seq_query" | \
		sqlplus -s sys/$oracle_password as sysdba
	LN
}

#*> $1 db name
#*> $2 service name
#*>
#*> return 1 if db name or service name not exists, else return 0
#*>
#*> Si le crs n'est pas utilisé et que le pdb est fermé return 1
function service_exists
{
	if command_exists crsctl
	then
		if grep -qE "^PRCR-1001"<<<"$(srvctl config service -db $1 -service $2)"
		then
			return 1
		else
			return 0
		fi
	else # ne test pas la base $1
		# $1 service name
		function sql
		{
			set_sql_cmd "set term off echo off feed off tim off heading off;"
			set_sql_cmd "select count(*) from cdb_services where name = lower( '$1' );"
		}
		typeset -r ok="$(sqlplus_exec_query "$(sql $2)"|tail -1|tr -d [:space:])"
		[ "$ok" == "1" ] && return 0 || return 1
	fi
}

#*> $1	db name
#*> $2	service name
#*>
#*> exit 1 if service name not running else return 0
function exit_if_service_not_exists
{
	typeset	-r	db_name_l="$1"
	typeset	-r	service_name_l="$2"

	info -n "Database $db_name_l, service $service_name_l exists "
	if service_exists $db_name_l $service_name_l
	then
		info -f "$OK"
		LN
	else
		info -f "$KO"
		LN
		exit 1
	fi
}

#*> $1 db name
#*> $2 service name
#*>
#*> return 0 if service running else return 1
function service_running
{
	if command_exists crsctl
	then
		typeset -r db_name_l=$1
		typeset -r service_name_l=$(to_lower $2)
		grep -iqE "Service $service_name_l is running.*"<<<"$(LANG=C srvctl status service -db $db_name_l -s $service_name_l)"
	else
		grep -qi "Service \"$2\" has .*"<<<"$(lsnrctl status)"
	fi
}

#*> $1	db name
#*> $2	service name
#*>
#*> exit 1 if service name not running else return 0
function exit_if_service_not_running
{
	typeset	-r	db_name_l="$1"
	typeset	-r	service_name_l="$2"

	info -n "Database $db_name_l, service $service_name_l running "
	if service_running $db_name_l $service_name_l
	then
		info -f "$OK"
		LN
	else
		info -f "$KO"
		LN
		exit 1
	fi
}

#*>	$1 pdb name
#*>
#*> return associate oci service name
function mk_oci_service
{
	echo $(to_lower "$1")_oci
}

#*>	$1 pdb name
#*>
#*> return associate oci service name for stby
function mk_oci_stby_service
{
	echo $(to_lower "$1")_stby_oci
}

#*>	$1 pdb name
#*>
#*> return associate java service name
function mk_java_service
{
	echo $(to_lower "$1")_java
}

#*>	$1 pdb name
#*>
#*> return associate java service name
function mk_java_stby_service
{
	echo $(to_lower "$1")_stby_java
}

#*> print to stdout Oracle SW Version :
#*>	12.1.0.2, 12.2.0.1, 18.0.0.0
function read_orcl_version
{
	$ORACLE_HOME/OPatch/opatch lsinventory		|\
		grep -E "Oracle Database [0-9][0-9]."	|\
		awk '{ print $4 }'						|\
		cut -d. -f1-4
}

#*> print to stdout Oracle SW Version :
#*>	12.1, 12.2, 18.0
function read_orcl_release
{
	case "$(read_orcl_version)" in
		12.1.*)
			echo 12.1
			;;
		12.2.*)
			echo 12.2
			;;
		18.0*)
			echo 18.0
			;;
		*)
			echo "Unknow release"
	esac
}

#*> $1 db name
#*> return 0 if RAC One Node, else 1
function is_rac_one_node
{
	srvctl status database -db $1|grep -q "Online relocation: INACTIVE"
}


#*> return 0 for Enterprise Edition
#*> return 1 for Standard Edition
function is_oracle_enterprise_edition
{
	sqlplus -s sys/$oracle_password as sysdba									\
		<<<"select banner from v\$version where banner like '%Edition Release%';"	\
		|grep -q "Enterprise"
}

#*> $1 pdb name
#*> Print to stdout yes or no
function is_application_seed
{
	typeset	-r	pdbseed_name=$(to_upper $1)
	typeset	-r	query=\
"select
	application_pdb
from
	v\$containers
where
	name='$pdbseed_name\$SEED'
;"
	typeset val=$(sqlplus_exec_query "$query")
	[ x"$val" == x ] && echo no || echo yes
}

#*> return 0 if PDB $1 is refreshable, else return 1
function refreshable_pdb
{
	typeset	-r	lpdb=$(to_upper $1)
	typeset	-r	query=\
"select
	refresh_mode
from
	cdb_pdbs
where
	pdb_name='$lpdb'
;"
	[ "$(sqlplus_exec_query "$query"|tail -1)" == NONE ] && return 1 || return 0
}

#*> return 0 if PDB $1 exists, else return 1
function pdb_exists
{
	typeset	-r	lpdb=$(to_upper $1)
	typeset	-r	query="select name from v\$pdbs where name='$lpdb';"

	[ "$(sqlplus_exec_query "$query"|tail -1)" == $lpdb ] && return 0 || return 1
}

#*> $1 dblink name
#*> return 0 if dblink $1 exists, else return 1.
function dblink_exists
{
	typeset	-r query="select count(*) from cdb_db_links where db_link = upper( '$1' );"

	[ "$(sqlplus_exec_query "$query"|tail -1|tr -d [:space:])" == "1" ] && return 0 || return 1
}

#*> $1 dblink_name
#*> $2 user
#*> $3 password
#*> $4 tns alias
#*>
#*> Print to stdout ddl statement to create a db link.
function ddl_create_dblink
{
	set_sql_cmd "create database link $1 connect to $2 identified by $3 using '$4';"
}

#*>	$1	db link name
#*>	exit 1 if db link test failed. Test : select 1 from dual@$1;
function exit_if_test_dblink_failed
{
	info -n "Test database link $1 : select 1 from dual@$1; "
	if [ "$(sqlplus_exec_query "select 1 from dual@$1;" | tail -1 | tr -d [:space:])" == 1 ]
	then
		info -f "[$OK]"
		LN
	else
		info -f "[$KO]"
		exit 1
	fi
}

#*> $1 tns alias
#*> exit 1 if tnsping $1 failed.
function exit_if_tnsping_failed
{
	info -n "tnsping $1 "
	if ! tnsping $1 >/dev/null 2>&1
	then
		info -f "[$KO]"
		LN
		exit 1
	else
		info -f "[$OK]"
		LN
	fi
}

#*> $1 connect string
#*> $2 username
#*> return 0 if $1 exists, else return 1
function db_username_exists
{
typeset connect_string="$1"
shift
if [ "$1" == as ]
then
	typeset -r connect_string="$connect_string as $2"
	shift 2
fi

typeset	-r	username=$1

typeset	-r	query=\
"select
	count(*)
from
    dba_users
where
	username=upper( '$username' )
;"

	if [ "$(sqlplus_exec_query_with "$connect_string" "$query" | tail -1 | tr -d [:space:])" == 1 ]
	then
		return 0
	else
		return 1
	fi
}
