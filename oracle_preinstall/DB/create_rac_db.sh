#!/bin/bash

#	ts=4 sw=4

typeset -r ME=$0

typeset dbname=undef
typeset poolname=undef
typeset sysPassword=password
typeset memory_mb=3072
typeset dgdata=DATA
typeset dgfra=FRA
typeset templateName=General_Purpose.dbc
typeset services_only=FALSE


function print_error_and_exit
{
	if [ $# -ne 0 ]
	then
		echo "ERROR> $@"
	fi

	echo "Usage : $ME"
	echo "	-db_name=<dbname>"
	echo "	-pool_name=<poolname>"
	echo "	[-sysPassword=<for sys & system>]	($sysPassword)"
	echo "	[-memory_mb=<mb>]			(${memory_mb}Mb)"
	echo "	[-dgdata=name]				($dgdata)"
	echo "	[-dgfra=name]				($dgfra)"
	echo "	[-templateName=<template file>	($templateName)"
	exit 1
}

while [ $# -ne 0 ]
do
	case $1 in
		-db_name=*)
			dbname=$(echo ${1##*=} | tr [:lower:] [:upper:])
			lower_dbname=$(echo $dbname | tr [:upper:] [:lower:])
			paramsql=param${dbname}.sql
			shift
			;;

		-pool_name=*)
			poolname=${1##*=}
			shift
			;;

		-sysPassword=*)
			sysPassword=${1##*=}
			shift
			;;

		-memory_mb=*)
			memory_mb=${1##*=}
			shift
			;;

		-dgdata=*)
			dgdata=${1##*=}
			shift
			;;

		-dgfra=*)
			dgfra=${1##*=}
			shift
			;;

		-templateName=*)
			templateName=${1##*=}
			shift
			if [ ! -f $ORACLE_HOME/assistants/dbca/templates/${templateName} ]
			then
				echo "Le fichier template '$templateName' n'existe pas."
				echo "Liste des templates disponible : "
				(	cd $ORACLE_HOME/assistants/dbca/templates
					ls -rtl *dbc
				)
				exit 1
			fi
			;;

		-services_only)
			services_only=TRUE
			shift
			;;

		*)
			print_error_and_exit "Arg '$1' invalid."
			;;
	esac
done

if [ $services_only = FALSE ]
then
	echo ">> Create DB              : $dbname"
	echo ">> sys & system passwords : $sysPassword"
	echo ">> memory                 : ${memory_mb}Mb"
	echo ">> dg data                : $dgdata"
	echo ">> dg fra                 : $dgfra"
	echo ">> template               : $templateName"

	if [ $dbname = undef ]
	then
		print_error_and_exit "db name missing."
	fi

	if [ $poolname = undef ]
	then
		print_error_and_exit "pool name missing"
	fi

	srvctl status srvpool -g $poolname >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		current_host=$(hostname -s)
		second_host=${current_host:0:${#current_host}-2}

		case ${current_host:${#current_host}-2} in
			01)
				second_host="${second_host}02"
				;;

			02)
				second_host="${second_host}01"
				;;

			*)
				echo "Error id invalid"
				exit 1
				;;
		esac

		echo "Création du srvpool $poolname sur le serveurs ${current_host} et ${second_host}"

		srvctl add srvpool -g $poolname -n "${current_host},${second_host}"
		if [ $? -ne 0 ]
		then
			echo "Creation failed."
			exit 1
		fi
	else
		echo "Le pool existe :"
		srvctl status srvpool -g $poolname
	fi

	echo "Lancement de dbca"
	#	Ne pas utiliser -nodelist pour une service manageed
set -x
	dbca	-createDatabase		 									\
				-silent												\
			-templateName General_Purpose.dbc						\
			-gdbName $dbname										\
			-sysPassword $sysPassword								\
			-systemPassword	$sysPassword							\
			-emConfiguration none									\
			-redoLogFileSize 512									\
			-policyManaged											\
				-serverPoolName ${poolname}						\
			-storageType ASM										\
				-diskGroupName DATA									\
				-recoveryGroupName FRA								\
			-automaticMemoryManagement true							\
			-totalMemory $memory_mb									\
			-characterSet	AL32UTF8								\
			-initParams		nls_language=FRENCH,NLS_TERRITORY=FRANCE
set +x
	#	Même si erreur dbca retourne toujours 0
fi

echo "Creation de 3 services : "

echo "service ${lower_dbname}_batch"
srvctl add service -d ${dbname} -g ${poolname} -c uniform -s ${lower_dbname}_batch -e SELECT -m BASIC -B THROUGHPUT
if [ $? -ne 0 ]
then
	echo "FAILED...."
	exit 1
fi
srvctl start service -d $dbname -s ${lower_dbname}_batch

echo "service ${lower_dbname}_oltp"
srvctl add service -d ${dbname} -g ${poolname} -c uniform -s ${lower_dbname}_oltp -e SELECT -m BASIC -B THROUGHPUT
srvctl start service -d $dbname -s ${lower_dbname}_oltp

echo "service ${lower_dbname}_report"
srvctl add service -d ${dbname} -g ${poolname} -c uniform -s ${lower_dbname}_report -e SELECT -m BASIC -B THROUGHPUT
srvctl start service -d $dbname -s ${lower_dbname}_report

sleep 10
echo "Les tablespaces seront par défaut en BIGFILE"
echo $dbname | . oraenv
sqlplus -s / as sysdba<<EOS
	alter database set default bigfile tablespace;
EOS

if [ -f $paramsql ]
then
	sqlplus -s / as sysdba<<EOS
	@$paramsql
EOS
fi

$CRS_HOME/bin/crsctl status res -t

srvctl config database -d $dbname
