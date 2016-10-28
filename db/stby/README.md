Table of Contents
=================

  * [Table of Contents](#table-of-contents)
  * [Création d'un dataguard.](#création-dun-dataguard)
    * [Pré requis.](#pré-requis)
    * [Etablir les équivalences ssh entre les 2 serveurs pour le compte Oracle.](#etablir-les-équivalences-ssh-entre-les-2-serveurs-pour-le-compte-oracle)
    * [Etat des lieux :](#etat-des-lieux-)
    * [Création du dataguard.](#création-du-dataguard)
  * [Description du script : create_dataguard.sh](#description-du-script--create_dataguardsh)
  * [Actions testées :](#actions-testées-)
  * [Prochaine étape.](#prochaine-étape)
  * [Log pour garder une trace claire sur les étapes.](#log-pour-garder-une-trace-claire-sur-les-étapes)

--------------------------------------------------------------------------------

#	Création d'un dataguard.
  La standby sera en 'real time apply' et ouverte en lecture seule.

##	Pré requis.
 - [Créer 2 serveurs, ex : srvmars01 & srvvenus01.](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/README.md)

   **Important** : Ne pas exécuter le second ./define_new_server.sh tant que le premier ./clone_master.sh n'est pas finie.

 - [Créer une base sur le serveur mars.](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)

## Etablir les équivalences ssh entre les 2 serveurs pour le compte Oracle.
 - Sur le poste client aller dans le répertoire `~/plescripts/ssh`

 - Etablir l'équivalence ssh entre les comptes oracle des 2 serveurs.

   Exécuter la commande :

   `./setup_ssh_equivalence.sh -server1=srvmars01 -server2=srvvenus01 -user1=oracle`

## Etat des lieux :
 - Initiallement la base est créées comme une SINGLE, les services sur la PDB mars01 sont minimaux :
	```
	oracle@srvmars01:MARS:oracle> srvctl config database -db mars
	Database unique name: MARS
	Database name: MARS
	Oracle home: /u01/app/oracle/12.1.0.2/dbhome_1
	Oracle user: oracle
	Spfile: +DATA/MARS/PARAMETERFILE/spfile.269.922379953
	Password file:
	Domain:
	Start options: open
	Stop options: immediate
	Database role: PRIMARY
	Management policy: AUTOMATIC
	Disk Groups: FRA,DATA
	Services: pdbmars01_java,pdbmars01_oci
	OSDBA group:
	OSOPER group:
	Database instance: MARS
	```

	Les services existants :
	```
	oracle@srvmars01:MARS:oracle> srvctl status service -db mars
	Service pdbmars01_java is running
	Service pdbmars01_oci is running
	```

	On a une base (CDB) nommée 'mars' ayant 1 PDB nommée 'mars01', la pdb est accessible
	par les services pdbmars01_[java|oci]

 - Le second serveur 'srvvenus01' n'a pas de base.

	```
	oracle@srvvenus01:NOSID:oracle> crsctl stat res -t
	--------------------------------------------------------------------------------
	Name           Target  State        Server                   State details
	--------------------------------------------------------------------------------
	Local Resources
	--------------------------------------------------------------------------------
	ora.DATA.dg
				   ONLINE  ONLINE       srvvenus01               STABLE
	ora.FRA.dg
				   ONLINE  ONLINE       srvvenus01               STABLE
	ora.LISTENER.lsnr
				   ONLINE  ONLINE       srvvenus01               STABLE
	ora.asm
				   ONLINE  ONLINE       srvvenus01               Started,STABLE
	ora.ons
				   OFFLINE OFFLINE      srvvenus01               STABLE
	--------------------------------------------------------------------------------
	Cluster Resources
	--------------------------------------------------------------------------------
	ora.cssd
		  1        ONLINE  ONLINE       srvvenus01               STABLE
	ora.diskmon
		  1        OFFLINE OFFLINE                               STABLE
	ora.evmd
		  1        ONLINE  ONLINE       srvvenus01               STABLE
	--------------------------------------------------------------------------------
	```

##	Création du dataguard.
 - Se connecter avec le compte oracle sur le serveur 'srvmars01' et charger l'environnement de la base.

 - Exécuter le script :
	```
	oracle@srvmars01:MARS:oracle> cd db/stby/
	oracle@srvmars01:MARS:stby> ./create_dataguard.sh -standby=venus -standby_host=srvvenus01
	```

--------------------------------------------------------------------------------

# Description du script : `create_dataguard.sh`
 * Configuration du réseau :
   * Mise à jour du fichier tnsnames.ora pour que les bases puissent se joindre.
   * Ajout d'une entrée statique dans le listener sur les 2 serveurs pour le duplicate et le dataguard.

 * Avant de lancer le duplicate :
   * Copie du fichier password vers la standby.
   * Création du répertoire adump sur la standby.
   * Démarre la standby en mount avec un pfile ne contenant que le paramètre db_name
   * Configuration de la base primaire :
     * Ajout des SRLs : 1 groupe de plus que pour les redologs.
     * standby_file_management = AUTO
     * fal_server= standby name
     * dg_broker_config_file1 ='+DATA/....' & dg_broker_config_file2='+FRA/....'
     * dg_broker_start = true
     * Passe la base en force logging
   
 * Script RMAN :

	```
	RMAN> run {
	2> 	allocate channel prim1 type disk;
	3> 	allocate channel prim2 type disk;
	4> 	allocate auxiliary channel stby1 type disk;
	5> 	allocate auxiliary channel stby2 type disk;
	6> 	duplicate target database for standby from active database
	7> 	spfile
	8> 		parameter_value_convert 'URANUS','VENUS'
	9> 		set db_unique_name='VENUS'
	10> 		set db_create_file_dest='+DATA'
	11> 		set db_recovery_file_dest='+FRA'
	12> 		set control_files='+DATA','+FRA'
	13> 		set cluster_database='false'
	14> 		set fal_server='URANUS'
	15> 		nofilenamecheck
	16> 	 ;
	17> }
	18> 
	```

 * Après le duplicate :
   * Ajout de la base dans le GI
   * Redémarre la base en mount et démarre le recover.
   * Lance une sauvegarde rman.

 * Services.

   Il y a 4 services par instance. Il y a 1 service pour les connexions OCI et 1
   service pour les connexions JAVA. Les 2 autres ont leurs correspondances pour la
   standby (accès en lecture seule).

   Aucun des services de la standby ne sont démarés

 * Configuration du Data Guard broker
   * Les 2 instances sont ajoutées.
   * La base standby est ouverte en RO, les services nécessaires sont donc démarrés.

--------------------------------------------------------------------------------

# Actions testées :

  * switchover : [log](https://github.com/PhilippeLeroux/plescripts/database_servers/switchover.md)
  * faileover : [test](https://github.com/PhilippeLeroux/plescripts/wiki/faileover)
  * reinstate, si le reinstate n'est pas possible le script `create_dataguard.sh`
  avec le paramètre `-create_primary_cfg=no` permet de recréer la standby.
  * Convertion en physical vers snapshot et snapshot vers physical.

--------------------------------------------------------------------------------

#	Prochaine étape.
 * L'observer : sur K2 ??
 * Tester si l'ajout d'un 3e standby peut se faire sans modification du script.

--------------------------------------------------------------------------------

# Log pour garder une trace claire sur les étapes.
```
# Running : ./create_dataguard.sh -standby=uranus -standby_host=srvuranus01
# Create dataguard :
# 	- between database VENUS on srvvenus01
# 	- and database URANUS on srvuranus01

17h27> /home/oracle/plescripts/shell/test_ssh_equi.sh -user=oracle -server=srvuranus01
# Running : /home/oracle/plescripts/shell/test_ssh_equi.sh -user=oracle -server=srvuranus01
17h27> ssh -o BatchMode=yes oracle@srvuranus01 true

17h27> ssh srvuranus01 ps -ef | grep -qE 'ora_pmon_[U]RANUS'
< ssh return 1
# Dataguard broker : 0 database configured.
# =========================================================================================================
17h27> rm -f /u01/app/oracle/12.1.0.2/dbhome_1/network/admin/tnsnames.ora
# Create file /u01/app/oracle/12.1.0.2/dbhome_1/network/admin/tnsnames.ora
# Add alias VENUS
# Add alias URANUS

# Copy tnsname.ora from srvvenus01 to srvuranus01
17h27> scp /u01/app/oracle/12.1.0.2/dbhome_1/network/admin/tnsnames.ora srvuranus01:/u01/app/oracle/12.1.0.2/dbhome_1/network/admin/tnsnames.ora

# =========================================================================================================
# Add static listeners on srvvenus01 : 
# On SINGLE GLOBAL_DBNAME == SID_NAME
17h27> chmod ug=rwx /tmp/setup_listener.sh
17h27> sudo -u grid -i /tmp/setup_listener.sh
Already configured.

# =========================================================================================================
# Add static listeners on srvuranus01 : 
# On SINGLE GLOBAL_DBNAME == SID_NAME
17h27> chmod ug=rwx /tmp/setup_listener.sh
17h27> scp /tmp/setup_listener.sh srvuranus01:/tmp/setup_listener.sh
17h27> ssh -t srvuranus01 sudo -u grid -i /tmp/setup_listener.sh
Already configured.
Connection to srvuranus01 closed.

# =========================================================================================================
# Add stdby redo log
# VENUS : 3 redo logs of 128M
#  --> Add 4 SRLs of 128M
17h27> sqlplus -s sys/Oracle12 as sysdba

SQL> alter database add standby logfile thread 1 size 128M;

Database altered.

Elapsed: 00:00:05.93

SQL> alter database add standby logfile thread 1 size 128M;

Database altered.

Elapsed: 00:00:06.40

SQL> alter database add standby logfile thread 1 size 128M;

Database altered.

Elapsed: 00:00:05.09

SQL> alter database add standby logfile thread 1 size 128M;

Database altered.

Elapsed: 00:00:06.07


17h27> sqlplus -s sys/Oracle12 as sysdba
# 

SQL> set lines 130 pages 45

SQL> col member for a45

SQL> select * from v$logfile order by type, group#;

    GROUP# STATUS  TYPE    MEMBER                                        IS_     CON_ID                                           
---------- ------- ------- --------------------------------------------- --- ----------                                           
         1         ONLINE  +DATA/VENUS/ONLINELOG/group_1.269.923593701   NO           0                                           
         1         ONLINE  +FRA/VENUS/ONLINELOG/group_1.259.923593705    YES          0                                           
         2         ONLINE  +DATA/VENUS/ONLINELOG/group_2.270.923593707   NO           0                                           
         2         ONLINE  +FRA/VENUS/ONLINELOG/group_2.260.923593711    YES          0                                           
         3         ONLINE  +DATA/VENUS/ONLINELOG/group_3.271.923593715   NO           0                                           
         3         ONLINE  +FRA/VENUS/ONLINELOG/group_3.261.923593717    YES          0                                           
         4         STANDBY +DATA/VENUS/ONLINELOG/group_4.273.923678843   NO           0                                           
         4         STANDBY +FRA/VENUS/ONLINELOG/group_4.316.923678845    YES          0                                           
         5         STANDBY +DATA/VENUS/ONLINELOG/group_5.279.923678849   NO           0                                           
         5         STANDBY +FRA/VENUS/ONLINELOG/group_5.303.923678853    YES          0                                           
         6         STANDBY +DATA/VENUS/ONLINELOG/group_6.275.923678855   NO           0                                           
         6         STANDBY +FRA/VENUS/ONLINELOG/group_6.278.923678857    YES          0                                           
         7         STANDBY +DATA/VENUS/ONLINELOG/group_7.274.923678861   NO           0                                           
         7         STANDBY +FRA/VENUS/ONLINELOG/group_7.333.923678863    YES          0                                           

14 rows selected.



# =========================================================================================================
# Setup primary database VENUS for duplicate & dataguard.
17h27> sqlplus -s sys/Oracle12 as sysdba

SQL> alter system set standby_file_management='AUTO' scope=both sid='*';

System altered.

Elapsed: 00:00:00.02

SQL> alter system set fal_server='URANUS' scope=both sid='*';

System altered.

Elapsed: 00:00:00.01

SQL> alter system set dg_broker_config_file1 = '+DATA/VENUS/dr1db_VENUS.dat' scope=both sid='*';

System altered.

Elapsed: 00:00:00.00

SQL> alter system set dg_broker_config_file2 = '+FRA/VENUS/dr2db_VENUS.dat' scope=both sid='*';

System altered.

Elapsed: 00:00:00.01

SQL> alter system set dg_broker_start=true scope=both sid='*';

System altered.

Elapsed: 00:00:00.01

SQL> alter database force logging;

Database altered.

Elapsed: 00:00:00.01


# =========================================================================================================
# Copie du fichier password.
17h27> scp /u01/app/oracle/12.1.0.2/dbhome_1/dbs/orapwVENUS srvuranus01:/u01/app/oracle/12.1.0.2/dbhome_1/dbs/orapwURANUS

# =========================================================================================================
# Création du répertoire /u01/app/oracle/URANUS/adump sur srvuranus01
17h27> ssh srvuranus01 mkdir -p /u01/app/oracle/admin/URANUS/adump

# =========================================================================================================
# Configure et démarre URANUS sur srvuranus01 (configuration minimaliste.)
Last login: Tue Sep 27 17:27:21 2016 from srvvenus01.orcl
                   _   _                              ___  _ 
                  | | | |_ __ __ _ _ __  _   _ ___   / _ \/ |
                  | | | | '__/ _` | '_ \| | | / __| | | | | |
                  | |_| | | | (_| | | | | |_| \__ \ | |_| | |
                   \___/|_|  \__,_|_| |_|\__,_|___/  \___/|_|
                                                             
                                           .-""-.
                                          (___/\ \
                                         ( |' ' ) )
                                       __) _\=_/  (
                                  ____(__.' `  \   )
                                .(/"-.._.('     ; (
                               /   / .     (' , |  )
                    _.`'---.._/   /.__ ____.'_| |_/
                   '-'``'-._     /  | `-........'
                     jgs    `;-"`;  |
                              `'.__/

rm -f /u01/app/oracle/12.1.0.2/dbhome_1/dbs/sp*URANUS* /u01/app/oracle/12.1.0.2/dbhome_1/dbs/init*URANUS*
echo "db_name='URANUS'" > /u01/app/oracle/12.1.0.2/dbhome_1/dbs/initURANUS.ora
export ORACLE_SID=URANUS
\sqlplus -s sys/Oracle12 as sysdba<<XXX
startup nomount
XXX
exit
]0;oracle@srvuranus01:~[?1034horacle@srvuranus01:NOSID:~> rm -f /u01/app/oracle/12.1.0.2/dbhome_1/dbs/sp*URANU S* /u01/app/oracle/12.1.0.2/dbhome_1/dbs/init*URANUS*
]0;oracle@srvuranus01:~oracle@srvuranus01:NOSID:~> echo "db_name='URANUS'" > /u01/app/oracle/12.1.0.2/d bhome_1/dbs/initURANUS.ora
]0;oracle@srvuranus01:~oracle@srvuranus01:NOSID:~> export ORACLE_SID=URANUS
]0;oracle@srvuranus01:~oracle@srvuranus01:URANUS:~> \sqlplus -s sys/Oracle12 as sysdba<<XXX
> startup nomount
> XXX
ORACLE instance started.

Total System Global Area  234881024 bytes
Fixed Size		    2922904 bytes
Variable Size		  176162408 bytes
Database Buffers	   50331648 bytes
Redo Buffers		    5464064 bytes
]0;oracle@srvuranus01:~oracle@srvuranus01:URANUS:~> exit
logout

# =========================================================================================================
# Info :
17h27> tnsping VENUS | tail -3
Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP) (HOST = srvvenus01) (PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = VENUS)))
OK (0 msec)

17h27> tnsping URANUS | tail -3
Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION = (ADDRESS = (PROTOCOL = TCP) (HOST = srvuranus01) (PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = URANUS)))
OK (10 msec)

# =========================================================================================================
# Run duplicate :
17h27> rman target sys/Oracle12@VENUS auxiliary sys/Oracle12@URANUS @/tmp/duplicate.rman

Recovery Manager: Release 12.1.0.2.0 - Production on Tue Sep 27 17:27:54 2016

Copyright (c) 1982, 2014, Oracle and/or its affiliates.  All rights reserved.

connected to target database: VENUS (DBID=2921024627)
connected to auxiliary database: URANUS (not mounted)

RMAN> run {
2> 	allocate channel prim1 type disk;
3> 	allocate channel prim2 type disk;
4> 	allocate auxiliary channel stby1 type disk;
5> 	allocate auxiliary channel stby2 type disk;
6> 	duplicate target database for standby from active database
7> 	spfile
8> 		parameter_value_convert 'VENUS','URANUS'
9> 		set db_unique_name='URANUS'
10> 		set db_create_file_dest='+DATA'
11> 		set db_recovery_file_dest='+FRA'
12> 		set control_files='+DATA','+FRA'
13> 		set cluster_database='false'
14> 		set fal_server='VENUS'
15> 		nofilenamecheck
16> 	 ;
17> }
18> 
using target database control file instead of recovery catalog
allocated channel: prim1
channel prim1: SID=277 device type=DISK

allocated channel: prim2
channel prim2: SID=38 device type=DISK

allocated channel: stby1
channel stby1: SID=13 device type=DISK

allocated channel: stby2
channel stby2: SID=173 device type=DISK

Starting Duplicate Db at 27-SEP-2016 17:27:58

contents of Memory Script:
{
   backup as copy reuse
   targetfile  '/u01/app/oracle/12.1.0.2/dbhome_1/dbs/orapwVENUS' auxiliary format 
 '/u01/app/oracle/12.1.0.2/dbhome_1/dbs/orapwURANUS'   ;
   restore clone from service  'VENUS' spfile to 
 '/u01/app/oracle/12.1.0.2/dbhome_1/dbs/spfileURANUS.ora';
   sql clone "alter system set spfile= ''/u01/app/oracle/12.1.0.2/dbhome_1/dbs/spfileURANUS.ora''";
}
executing Memory Script

Starting backup at 27-SEP-2016 17:27:59
Finished backup at 27-SEP-2016 17:28:00

Starting restore at 27-SEP-2016 17:28:00

channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: restoring SPFILE
output file name=/u01/app/oracle/12.1.0.2/dbhome_1/dbs/spfileURANUS.ora
channel stby1: restore complete, elapsed time: 00:00:02
Finished restore at 27-SEP-2016 17:28:01

sql statement: alter system set spfile= ''/u01/app/oracle/12.1.0.2/dbhome_1/dbs/spfileURANUS.ora''

contents of Memory Script:
{
   sql clone "alter system set  audit_file_dest = 
 ''/u01/app/oracle/admin/URANUS/adump'' comment=
 '''' scope=spfile";
   sql clone "alter system set  dg_broker_config_file1 = 
 ''+DATA/URANUS/dr1db_VENUS.dat'' comment=
 '''' scope=spfile";
   sql clone "alter system set  dg_broker_config_file2 = 
 ''+FRA/URANUS/dr2db_VENUS.dat'' comment=
 '''' scope=spfile";
   sql clone "alter system set  dispatchers = 
 ''(PROTOCOL=TCP) (SERVICE=URANUSXDB)'' comment=
 '''' scope=spfile";
   sql clone "alter system set  db_unique_name = 
 ''URANUS'' comment=
 '''' scope=spfile";
   sql clone "alter system set  db_create_file_dest = 
 ''+DATA'' comment=
 '''' scope=spfile";
   sql clone "alter system set  db_recovery_file_dest = 
 ''+FRA'' comment=
 '''' scope=spfile";
   sql clone "alter system set  control_files = 
 ''+DATA'', ''+FRA'' comment=
 '''' scope=spfile";
   sql clone "alter system set  cluster_database = 
 false comment=
 '''' scope=spfile";
   sql clone "alter system set  fal_server = 
 ''VENUS'' comment=
 '''' scope=spfile";
   shutdown clone immediate;
   startup clone nomount;
}
executing Memory Script

sql statement: alter system set  audit_file_dest =  ''/u01/app/oracle/admin/URANUS/adump'' comment= '''' scope=spfile

sql statement: alter system set  dg_broker_config_file1 =  ''+DATA/URANUS/dr1db_VENUS.dat'' comment= '''' scope=spfile

sql statement: alter system set  dg_broker_config_file2 =  ''+FRA/URANUS/dr2db_VENUS.dat'' comment= '''' scope=spfile

sql statement: alter system set  dispatchers =  ''(PROTOCOL=TCP) (SERVICE=URANUSXDB)'' comment= '''' scope=spfile

sql statement: alter system set  db_unique_name =  ''URANUS'' comment= '''' scope=spfile

sql statement: alter system set  db_create_file_dest =  ''+DATA'' comment= '''' scope=spfile

sql statement: alter system set  db_recovery_file_dest =  ''+FRA'' comment= '''' scope=spfile

sql statement: alter system set  control_files =  ''+DATA'', ''+FRA'' comment= '''' scope=spfile

sql statement: alter system set  cluster_database =  false comment= '''' scope=spfile

sql statement: alter system set  fal_server =  ''VENUS'' comment= '''' scope=spfile

Oracle instance shut down

connected to auxiliary database (not started)
Oracle instance started

Total System Global Area     671088640 bytes

Fixed Size                     2928008 bytes
Variable Size                637534840 bytes
Database Buffers              25165824 bytes
Redo Buffers                   5459968 bytes
allocated channel: stby1
channel stby1: SID=16 device type=DISK
allocated channel: stby2
channel stby2: SID=253 device type=DISK

contents of Memory Script:
{
   sql clone "alter system set  control_files = 
  ''+DATA/URANUS/CONTROLFILE/current.270.923678903'', ''+FRA/URANUS/CONTROLFILE/current.276.923678903'' comment=
 ''Set by RMAN'' scope=spfile";
   restore clone from service  'VENUS' standby controlfile;
}
executing Memory Script

sql statement: alter system set  control_files =   ''+DATA/URANUS/CONTROLFILE/current.270.923678903'', ''+FRA/URANUS/CONTROLFILE/current.276.923678903'' comment= ''Set by RMAN'' scope=spfile

Starting restore at 27-SEP-2016 17:28:24

channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: restoring control file
channel stby1: restore complete, elapsed time: 00:00:04
output file name=+DATA/URANUS/CONTROLFILE/current.257.923678905
output file name=+FRA/URANUS/CONTROLFILE/current.291.923678905
Finished restore at 27-SEP-2016 17:28:28

contents of Memory Script:
{
   sql clone 'alter database mount standby database';
}
executing Memory Script

sql statement: alter database mount standby database

contents of Memory Script:
{
   set newname for clone tempfile  1 to new;
   set newname for clone tempfile  2 to new;
   set newname for clone tempfile  3 to new;
   switch clone tempfile all;
   set newname for clone datafile  1 to new;
   set newname for clone datafile  3 to new;
   set newname for clone datafile  4 to new;
   set newname for clone datafile  5 to new;
   set newname for clone datafile  6 to new;
   set newname for clone datafile  7 to new;
   set newname for clone datafile  8 to new;
   set newname for clone datafile  9 to new;
   set newname for clone datafile  10 to new;
   restore
   from service  'VENUS'   clone database
   ;
   sql 'alter system archive log current';
}
executing Memory Script

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

renamed tempfile 1 to +DATA in control file
renamed tempfile 2 to +DATA in control file
renamed tempfile 3 to +DATA in control file

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

executing command: SET NEWNAME

Starting restore at 27-SEP-2016 17:28:33

channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: specifying datafile(s) to restore from backup set
channel stby1: restoring datafile 00001 to +DATA
channel stby2: starting datafile backup set restore
channel stby2: using network backup set from service VENUS
channel stby2: specifying datafile(s) to restore from backup set
channel stby2: restoring datafile 00003 to +DATA
channel stby1: restore complete, elapsed time: 00:00:55
channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: specifying datafile(s) to restore from backup set
channel stby1: restoring datafile 00004 to +DATA
channel stby2: restore complete, elapsed time: 00:00:55
channel stby2: starting datafile backup set restore
channel stby2: using network backup set from service VENUS
channel stby2: specifying datafile(s) to restore from backup set
channel stby2: restoring datafile 00005 to +DATA
channel stby1: restore complete, elapsed time: 00:00:16
channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: specifying datafile(s) to restore from backup set
channel stby1: restoring datafile 00006 to +DATA
channel stby2: restore complete, elapsed time: 00:00:16
channel stby2: starting datafile backup set restore
channel stby2: using network backup set from service VENUS
channel stby2: specifying datafile(s) to restore from backup set
channel stby2: restoring datafile 00007 to +DATA
channel stby1: restore complete, elapsed time: 00:00:01
channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: specifying datafile(s) to restore from backup set
channel stby1: restoring datafile 00008 to +DATA
channel stby1: restore complete, elapsed time: 00:00:26
channel stby1: starting datafile backup set restore
channel stby1: using network backup set from service VENUS
channel stby1: specifying datafile(s) to restore from backup set
channel stby1: restoring datafile 00009 to +DATA
channel stby2: restore complete, elapsed time: 00:00:32
channel stby2: starting datafile backup set restore
channel stby2: using network backup set from service VENUS
channel stby2: specifying datafile(s) to restore from backup set
channel stby2: restoring datafile 00010 to +DATA
channel stby2: restore complete, elapsed time: 00:00:04
channel stby1: restore complete, elapsed time: 00:00:31
Finished restore at 27-SEP-2016 17:30:43

sql statement: alter system archive log current

contents of Memory Script:
{
   switch clone datafile all;
}
executing Memory Script

datafile 1 switched to datafile copy
input datafile copy RECID=48 STAMP=923679043 file name=+DATA/URANUS/DATAFILE/system.260.923678913
datafile 3 switched to datafile copy
input datafile copy RECID=49 STAMP=923679043 file name=+DATA/URANUS/DATAFILE/sysaux.271.923678913
datafile 4 switched to datafile copy
input datafile copy RECID=50 STAMP=923679043 file name=+DATA/URANUS/DATAFILE/undotbs1.276.923678969
datafile 5 switched to datafile copy
input datafile copy RECID=51 STAMP=923679043 file name=+DATA/URANUS/3D6B39C16C552400E0530E64AAC09F9E/DATAFILE/system.259.923678969
datafile 6 switched to datafile copy
input datafile copy RECID=52 STAMP=923679043 file name=+DATA/URANUS/DATAFILE/users.272.923678985
datafile 7 switched to datafile copy
input datafile copy RECID=53 STAMP=923679043 file name=+DATA/URANUS/3D6B39C16C552400E0530E64AAC09F9E/DATAFILE/sysaux.275.923678985
datafile 8 switched to datafile copy
input datafile copy RECID=54 STAMP=923679043 file name=+DATA/URANUS/3D6B5BA2DD912F82E0530E64AAC01A8D/DATAFILE/system.267.923678987
datafile 9 switched to datafile copy
input datafile copy RECID=55 STAMP=923679043 file name=+DATA/URANUS/3D6B5BA2DD912F82E0530E64AAC01A8D/DATAFILE/sysaux.282.923679015
datafile 10 switched to datafile copy
input datafile copy RECID=56 STAMP=923679044 file name=+DATA/URANUS/3D6B5BA2DD912F82E0530E64AAC01A8D/DATAFILE/users.264.923679019
Finished Duplicate Db at 27-SEP-2016 17:31:33
released channel: prim1
released channel: prim2
released channel: stby1
released channel: stby2

Recovery Manager complete.
17h31< rman running time : 3mn40s
# =========================================================================================================
# Backup standby alertlog :
17h31> ssh srvuranus01 '. .profile; mv /u01/app/oracle/diag/rdbms/uranus/URANUS/trace/alert_URANUS.log /u01/app/oracle/diag/rdbms/uranus/URANUS/trace/alert_URANUS.log.after_duplicate'

# =========================================================================================================
# GI : register standby database on srvuranus01 :
17h31> ssh -t srvuranus01 ". .profile; srvctl add database -db URANUS -oraclehome /u01/app/oracle/12.1.0.2/dbhome_1 -spfile /u01/app/oracle/12.1.0.2/dbhome_1/dbs/spfileURANUS.ora -role physical_standby -dbname VENUS -diskgroup DATA,FRA -verbose"
Connection to srvuranus01 closed.

# URANUS : mount & start recover :
17h31> sqlplus -s sys/Oracle12@URANUS as sysdba

SQL> shutdown immediate;
ORA-01109: base de donnees non ouverte 


Database dismounted.
ORACLE instance shut down.

SQL> startup mount;
ORACLE instance started.

Total System Global Area  671088640 bytes                                       
Fixed Size                  2928008 bytes                                       
Variable Size             637534840 bytes                                       
Database Buffers           25165824 bytes                                       
Redo Buffers                5459968 bytes                                       
Database mounted.

SQL> recover managed standby database disconnect;
Media recovery complete.

# Wait recover : 10/10s

17h32> /home/oracle/plescripts/db/drop_all_services.sh -db=VENUS
# Running : /home/oracle/plescripts/db/drop_all_services.sh -db=VENUS
17h32> srvctl stop service -db VENUS -service pdbVENUS01_java
17h32> srvctl remove service -db VENUS -service pdbVENUS01_java

17h32> srvctl stop service -db VENUS -service pdbVENUS01_oci
17h32> srvctl remove service -db VENUS -service pdbVENUS01_oci

# =========================================================================================================
# Create stby service for pdb VENUS01 on cdb VENUS
17h32> /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=VENUS -pdbName=VENUS01 -role=primary
# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=VENUS -pdbName=VENUS01 -role=primary
# =============================================================================
# create service pdbVENUS01_oci on pluggable VENUS01 (db = VENUS).

17h32> srvctl                                   \
           add service -service pdbVENUS01_oci  \
               -pdb VENUS01 -db VENUS           \
               -role           primary          \
               -policy         automatic        \
               -failovertype   select           \
               -failovermethod basic            \
               -failoverretry  3                \
               -failoverdelay  60               \
               -clbgoal        long             \
               -rlbgoal        throughput       

17h32> srvctl start service -service pdbVENUS01_oci -db VENUS

# =============================================================================
# create service pdbVENUS01_java on pluggable VENUS01 (db = VENUS)

17h32> srvctl                                    \
           add service -service pdbVENUS01_java  \
               -pdb VENUS01 -db VENUS            \
               -role           primary           \
               -policy         automatic         \
               -failovertype   select            \
               -failovermethod basic             \
               -failoverretry  3                 \
               -failoverdelay  60                \
               -clbgoal        long              \
               -rlbgoal        throughput        

17h32> srvctl start service -service pdbVENUS01_java -db VENUS


17h32> /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=VENUS -pdbName=VENUS01 -role=physical_standby
# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=VENUS -pdbName=VENUS01 -role=physical_standby
# =============================================================================
# create service pdbVENUS01_stby_oci on pluggable VENUS01 (db = VENUS).

17h32> srvctl                                        \
           add service -service pdbVENUS01_stby_oci  \
               -pdb VENUS01 -db VENUS                \
               -role           physical_standby      \
               -policy         automatic             \
               -failovertype   select                \
               -failovermethod basic                 \
               -failoverretry  3                     \
               -failoverdelay  60                    \
               -clbgoal        long                  \
               -rlbgoal        throughput            

17h32> srvctl start service -service pdbVENUS01_stby_oci -db VENUS

# =============================================================================
# create service pdbVENUS01_stby_java on pluggable VENUS01 (db = VENUS)

17h32> srvctl                                         \
           add service -service pdbVENUS01_stby_java  \
               -pdb VENUS01 -db VENUS                 \
               -role           physical_standby       \
               -policy         automatic              \
               -failovertype   select                 \
               -failovermethod basic                  \
               -failoverretry  3                      \
               -failoverdelay  60                     \
               -clbgoal        long                   \
               -rlbgoal        throughput             

17h32> srvctl start service -service pdbVENUS01_stby_java -db VENUS


# Create services for pdb VENUS01 on cdb URANUS
17h32> ssh -t -t srvuranus01 '. .profile; /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=URANUS -pdbName=VENUS01 -role=primary -start=no'</dev/null
The Oracle base remains unchanged with value /u01/app/oracle
# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=URANUS -pdbName=VENUS01 -role=primary -start=no
# =============================================================================
# create service pdbVENUS01_oci on pluggable VENUS01 (db = URANUS).

17h32> srvctl                                   \
           add service -service pdbVENUS01_oci  \
               -pdb VENUS01 -db URANUS          \
               -role           primary          \
               -policy         automatic        \
               -failovertype   select           \
               -failovermethod basic            \
               -failoverretry  3                \
               -failoverdelay  60               \
               -clbgoal        long             \
               -rlbgoal        throughput       

# =============================================================================
# create service pdbVENUS01_java on pluggable VENUS01 (db = URANUS)

17h32> srvctl                                    \
           add service -service pdbVENUS01_java  \
               -pdb VENUS01 -db URANUS           \
               -role           primary           \
               -policy         automatic         \
               -failovertype   select            \
               -failovermethod basic             \
               -failoverretry  3                 \
               -failoverdelay  60                \
               -clbgoal        long              \
               -rlbgoal        throughput        

Connection to srvuranus01 closed.

17h32> ssh -t -t srvuranus01 '. .profile; /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=URANUS -pdbName=VENUS01 -role=physical_standby -start=no'</dev/null
The Oracle base remains unchanged with value /u01/app/oracle
# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=URANUS -pdbName=VENUS01 -role=physical_standby -start=no
# =============================================================================
# create service pdbVENUS01_stby_oci on pluggable VENUS01 (db = URANUS).

17h32> srvctl                                        \
           add service -service pdbVENUS01_stby_oci  \
               -pdb VENUS01 -db URANUS               \
               -role           physical_standby      \
               -policy         automatic             \
               -failovertype   select                \
               -failovermethod basic                 \
               -failoverretry  3                     \
               -failoverdelay  60                    \
               -clbgoal        long                  \
               -rlbgoal        throughput            

# =============================================================================
# create service pdbVENUS01_stby_java on pluggable VENUS01 (db = URANUS)

17h32> srvctl                                         \
           add service -service pdbVENUS01_stby_java  \
               -pdb VENUS01 -db URANUS                \
               -role           physical_standby       \
               -policy         automatic              \
               -failovertype   select                 \
               -failovermethod basic                  \
               -failoverretry  3                      \
               -failoverdelay  60                     \
               -clbgoal        long                   \
               -rlbgoal        throughput             

Connection to srvuranus01 closed.

# Stop stby services on primary VENUS :
17h32> srvctl stop service -db VENUS -service pdbVENUS01_stby_oci
17h32> srvctl stop service -db VENUS -service pdbVENUS01_stby_java

# =========================================================================================================
# Create data guard configuration.
# Wait data guard broker : 30/30s

create configuration 'DGCONF' as primary database is VENUS connect identifier is VENUS;
Configuration "DGCONF" created with primary database "venus"
enable configuration;


# Add standby URANUS to data guard configuration.
add database URANUS as connect identifier is URANUS maintained as physical;
Database "uranus" added
enable database URANUS;


# Waiting recover : 10/10s

# Open read only URANUS for Real Time Query
17h34> sqlplus -s sys/Oracle12@URANUS as sysdba

SQL> alter database open read only;

Database altered.

Elapsed: 00:00:13.35


17h34> /home/oracle/plescripts/db/stby/show_dataguard_cfg.sh
# Running : /home/oracle/plescripts/db/stby/show_dataguard_cfg.sh 
# =============================================================================
17h34> dgmgrl -silent sys/Oracle12
show configuration

Configuration - DGCONF

  Protection Mode: MaxPerformance
  Members:
  venus  - Primary database
    uranus - Physical standby database 

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS   (status updated 26 seconds ago)

# =============================================================================
17h34> dgmgrl -silent sys/Oracle12
show database venus

Database - venus

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    VENUS

Database Status:
SUCCESS

17h34> dgmgrl -silent sys/Oracle12
validate database venus

  Database Role:    Primary database

  Ready for Switchover:  Yes

  Flashback Database Status:
    venus:  Off

# =============================================================================
17h35> dgmgrl -silent sys/Oracle12
show database uranus

Database - uranus

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed 0 seconds ago)
  Apply Lag:          27 seconds (computed 0 seconds ago)
  Average Apply Rate: 6.00 KByte/s
  Real Time Query:    ON
  Instance(s):
    URANUS

Database Status:
SUCCESS

17h35> dgmgrl -silent sys/Oracle12
validate database uranus

  Database Role:     Physical standby database
  Primary Database:  venus

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Flashback Database Status:
    venus:   Off
    uranus:  Off

  Standby Apply-Related Information:
    Apply State:      Running
    Apply Lag:        29 seconds (computed 1 second ago)
    Apply Delay:      0 minutes

# script create_dataguard.sh running time : 7mn50s
```
