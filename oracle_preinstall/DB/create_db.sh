#!/bin/ksh

#	ts=4 sw=4

typeset -r ME=$0

typeset dbname=undef
typeset sysPassword=password
typeset memory_mb=3072
typeset dgdata=DATA
typeset dgfra=FRA
typeset templateName=General_Purpose.dbc


function print_error_and_exit
{
	if [ $# -ne 0 ]
	then
		echo "ERROR> $@"
	fi

	echo "Usage : $ME"
	echo "	-db_name=<dbname>"
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

		*)
			print_error_and_exit "Arg '$1' invalid."
			;;
	esac
done

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

dbca	-createDatabase -silent									\
		-templateName General_Purpose.dbc						\
		-gdbName $dbname										\
		-sysPassword $sysPassword								\
		-systemPassword	$sysPassword							\
		-emConfiguration none									\
		-redoLogFileSize 512									\
		-storageType ASM										\
			-diskGroupName DATA									\
			-recoveryGroupName FRA								\
		-automaticMemoryManagement true							\
		-totalMemory $memory_mb									\
		-characterSet	AL32UTF8								\
		-initParams		nls_language=FRENCH,NLS_TERRITORY=FRANCE

#	Même si erreur dbca retourne toujours 0

echo "Creation de 3 services : "

echo "service ${lower_dbname}_batch"
srvctl add service -d $dbname -s ${lower_dbname}_batch
if [ $? -ne 0 ]
then
	echo "FAILED...."
	exit 1
fi
srvctl start service -d $dbname -s ${lower_dbname}_batch

echo "service ${lower_dbname}_oltp"
srvctl add service -d $dbname -s ${lower_dbname}_oltp
srvctl start service -d $dbname -s ${lower_dbname}_oltp

echo "service ${lower_dbname}_report"
srvctl add service -d $dbname -s ${lower_dbname}_report
srvctl start service -d $dbname -s ${lower_dbname}_report

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
