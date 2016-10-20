# Intro
[Documentation](http://docs.oracle.com/database/121/ADMIN/cdb_pdb_admin.htm#ADMIN13663)

Rappel les bases sont créées en mode threaded (donc pas d'identification OS)

# Modification du scripts sqldeveloper.sh

	```
	[kangs<<racvbox>>sqldeveloper]$ cat sqldeveloper.sh
	#!/bin/bash
	echo "Stop nscd.service"
	sudo systemctl stop nscd.service
	echo

	export TNS_ADMIN=$HOME/sqldeveloper

	cd "`dirname $0`"/sqldeveloper/bin && bash sqldeveloper $*

	echo
	echo "Start nscd.service"
	sudo systemctl start nscd.service
	```

Exemple fichier tnsnames.ora pour les dataguards :

	```
	[kangs<<racvbox>>sqldeveloper]$ cat tnsnames.ora
	PDBVENUS01 =
		(DESCRIPTION =
			(FAILOVER=on)
			(LOAD_BALANCE=off)
			(ADDRESS_LIST=
				(ADDRESS = (PROTOCOL = TCP) (HOST = srvvenus01) (PORT = 1521) )
				(ADDRESS = (PROTOCOL = TCP) (HOST = srvuranus01) (PORT = 1521) )
			)
			(CONNECT_DATA =
				(SERVER = DEDICATED)
				(SERVICE_NAME = pdbVENUS01_java)
			)
		)
	```

# Connection au CDC :
`sqlplus sys/Oracle12 as sysdba`

# Connection au PDB :
* Il faut connaître le nom de la SCAN :

	```
	oracle@srvphilae01:PHILAE_2:oracle> srvctl config scan
	SCAN name: philae-scan, Network: 1
	Subnet IPv4: 192.170.100.0/255.255.255.0/eth0, static
	Subnet IPv6:
	SCAN 0 IPv4 VIP: 192.170.100.15
	SCAN VIP is enabled.
	SCAN VIP is individually enabled on nodes:
	SCAN VIP is individually disabled on nodes:
	SCAN 1 IPv4 VIP: 192.170.100.16
	SCAN VIP is enabled.
	SCAN VIP is individually enabled on nodes:
	SCAN VIP is individually disabled on nodes:
	SCAN 2 IPv4 VIP: 192.170.100.17
	SCAN VIP is enabled.
	SCAN VIP is individually enabled on nodes:
	SCAN VIP is individually disabled on nodes:
	```

* Il faut utiliser un des service pointant sur la PDB :

	```
	oracle@srvphilae01:PHILAE_2:oracle> srvctl config service -db philae
	Service name: pdbphilae01_java
	Server pool: poolAllNodes
	Cardinality: UNIFORM
	Disconnect: false
	Service role: PRIMARY
	Management policy: AUTOMATIC
	DTP transaction: false
	AQ HA notifications: true
	Global: false
	Commit Outcome: true
	Failover type: TRANSACTION
	Failover method: BASIC
	TAF failover retries:
	TAF failover delay:
	Connection Load Balancing Goal: LONG
	Runtime Load Balancing Goal: THROUGHPUT
	TAF policy specification: NONE
	Edition:
	Pluggable database name: philae01
	Maximum lag time: ANY
	SQL Translation Profile:
	Retention: 86400 seconds
	Replay Initiation Time: 300 seconds
	Session State Consistency: DYNAMIC
	GSM Flags: 0
	Service is enabled
	Service is individually enabled on nodes:
	Service is individually disabled on nodes:

	Service name: pdbphilae01_oci
	Server pool: poolAllNodes
	Cardinality: UNIFORM
	Disconnect: false
	Service role: PRIMARY
	Management policy: AUTOMATIC
	DTP transaction: false
	AQ HA notifications: false
	Global: false
	Commit Outcome: false
	Failover type: SESSION
	Failover method: BASIC
	TAF failover retries:
	TAF failover delay:
	Connection Load Balancing Goal: LONG
	Runtime Load Balancing Goal: THROUGHPUT
	TAF policy specification: NONE
	Edition:
	Pluggable database name: philae01
	Maximum lag time: ANY
	SQL Translation Profile:
	Retention: 86400 seconds
	Replay Initiation Time: 300 seconds
	Session State Consistency:
	GSM Flags: 0
	Service is enabled
	Service is individually enabled on nodes:
	Service is individually disabled on nodes:
	```

* Connection :

	Utilisation de la SCAN philae-scan sur le port 1521 et le service pdbphilae01_oci.

	```
	oracle@srvphilae01:PHILAE_2:oracle> sqlplus sys/Oracle12@//philae-scan:1521/pdbphilae01_oci as sysdba

	SQL*Plus: Release 12.1.0.2.0 Production on Tue Aug 30 11:41:13 2016

	Copyright (c) 1982, 2014, Oracle.  All rights reserved.


	Connected to:
	Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
	With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
	Advanced Analytics and Real Application Testing options

	SQL>
	```

	TODO : Créer un alias tns pour éviter l'ezconnect

# En vrac commandes/liens utils sur les PDBs.

[About CDB and PDB Information in Views](http://docs.oracle.com/database/121/ADMIN/cdb_mon.htm#ADMIN13980)

Les pdbs sont identifiés par le CON_ID, les valeurs pour un PDB vont de 3 à 254.

(Toutes) les vues v$ ont maintenant un homologue v$con_

Note : tous les scripts sont présents dans le répertoire plescripts/db/12c

(CDB)
```sql
SQL> @containers

    CON_ID NAME                           OPEN_MODE  Open time      Total size RECOVERY
---------- ------------------------------ ---------- -------------- ---------- --------
         1 CDB$ROOT                       READ WRITE 16/08/30 10:37          0 ENABLED
         2 PDB$SEED                       READ ONLY  16/08/30 10:37          1 ENABLED
         3 PHILAE01                       READ WRITE 16/08/30 10:37          1 ENABLED
```

SELECT CDB FROM V$DATABASE; return YES if CDB

Les Temp Files (CDB) :
```sql
COLUMN CON_ID FORMAT 999
COLUMN FILE_ID FORMAT 9999
COLUMN TABLESPACE_NAME FORMAT A15
COLUMN FILE_NAME FORMAT A45

SELECT CON_ID, FILE_ID, TABLESPACE_NAME, FILE_NAME
  FROM CDB_TEMP_FILES
  ORDER BY CON_ID;

CON_ID FILE_ID TABLESPACE_NAME FILE_NAME
------ ------- --------------- ---------------------------------------------
     1       1 TEMP            +DATA/PHILAE/TEMPFILE/temp.264.921160031
     3       3 TEMP            +DATA/PHILAE/3B35A82EE63D0748E0530B64AAC0ECD2
                               /TEMPFILE/temp.274.921161067
```

Les services (CDB)
```sql
COLUMN NETWORK_NAME FORMAT A30
COLUMN PDB FORMAT A15
COLUMN CON_ID FORMAT 999

SELECT PDB, NETWORK_NAME, CON_ID FROM CDB_SERVICES
  WHERE PDB IS NOT NULL AND
        CON_ID > 2
  ORDER BY PDB;

PDB             NETWORK_NAME                   CON_ID
--------------- ------------------------------ ------
PHILAE01        philae01                            3
PHILAE01        pdbphilae01_java                    3
PHILAE01        pdbphilae01_oci                     3
```

Le nom du container :
```sql
oracle@srvphilae01:PHILAE_2:12c> sp

SQL*Plus: Release 12.1.0.2.0 Production on Tue Aug 30 12:22:23 2016

Copyright (c) 1982, 2014, Oracle.  All rights reserved.


Connected to:
Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
Advanced Analytics and Real Application Testing options

SQL> SHOW CON_NAME

CON_NAME
------------------------------
CDB$ROOT
SQL> Disconnected from Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
Advanced Analytics and Real Application Testing options
oracle@srvphilae01:PHILAE_2:12c> sqlplus sys/Oracle12@//philae-scan:1521/pdbphilae01_oci as sysdba

SQL*Plus: Release 12.1.0.2.0 Production on Tue Aug 30 12:22:30 2016

Copyright (c) 1982, 2014, Oracle.  All rights reserved.


Connected to:
Oracle Database 12c Enterprise Edition Release 12.1.0.2.0 - 64bit Production
With the Partitioning, Real Application Clusters, Automatic Storage Management, OLAP,
Advanced Analytics and Real Application Testing options

SQL> SHOW CON_NAME

CON_NAME
------------------------------
PHILAE01
SQL>
```

Paramètres modifiable d'un PDB :
```sql
SELECT NAME FROM V$SYSTEM_PARAMETER
  WHERE ISPDB_MODIFIABLE = 'TRUE'
  ORDER BY NAME;
```

Historique des PDBs
```sql
COLUMN DB_NAME FORMAT A10
COLUMN CON_ID FORMAT 999
COLUMN PDB_NAME FORMAT A15
COLUMN OPERATION FORMAT A16
COLUMN OP_TIMESTAMP FORMAT A10
COLUMN CLONED_FROM_PDB_NAME FORMAT A15
 
SELECT DB_NAME, CON_ID, PDB_NAME, OPERATION, OP_TIMESTAMP, CLONED_FROM_PDB_NAME
  FROM CDB_PDB_HISTORY
  WHERE CON_ID > 2
  ORDER BY CON_ID;
```

SQL> create user ple identified by ple;

User created.

SQL> grant create session to ple;

