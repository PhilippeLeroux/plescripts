**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

### Création d'une base de donnée.

Remarque : si le master et K2 viennent d'être créés il est préférable d'installer
un serveur standalone ce qui permet de rapidement valider l'installation et la
configuration du poste client/host et des VMs master et K2.

1. Se connecter sur le serveur : `ssh oracle@srvdaisy01`

	Les connexions root, oracle et grid ne nécessitent pas de mot de passe, les
	clefs du poste client ayant été déployées sur tous les comptes.

2. Se déplacer dans le répertoire plescripts/db : `cd plescripts/db`

3. Exécution du script create_db.sh :

	```bash
	oracle@srvdaisy01:NOSID:db> ./create_db.sh -db=daisy
	# Running : ./create_db.sh -db=daisy
	# ===============================================================================
	# Remove all files on srvdaisy01
	11h49> rm -rf /u01/app/oracle/cfgtoollogs/dbca/*
	11h49> rm -rf /u01/app/oracle/diag/rdbms/daisy

	11h49> dbca                                     \
			   -createDatabase -silent              \
			   -databaseConfType RAC                \
			   -nodelist srvdaisy01,srvdaisy02      \
			   -gdbName DAISY                       \
			   -characterSet AL32UTF8               \
			   -storageType ASM                     \
				   -diskGroupName     DATA          \
				   -recoveryGroupName FRA           \
			   -templateName General_Purpose.dbc    \
			   -createAsContainerDatabase true      \
				   -numberOfPDBs     1              \
				   -pdbName          daisy01        \
				   -pdbAdminPassword Oracle12       \
			   -sysPassword    Oracle12             \
			   -systemPassword Oracle12             \
			   -redoLogFileSize 512                 \
			   -totalMemory 640                     \
			   -initParams threaded_execution=true,nls_language=FRENCH,NLS_TERRITORY=FRANCE,shared_pool_size=256M
	# Continue y/n ? y
	# y
	```
	
	Confirmer la création si les paramètres conviennent. Pour afficher la liste
	des paramètres modifiables : `./create_db.sh -h`

	La configuration de la base SINGLE ou RAC sera détectée automatiquement. 
	
	Pour une configuration de type RAC One Node ajouter le paramète -db_type=RACONENODE.
	
	Le service associé sera ron_<nom_du_serveur ou est crée la base> (ron = **r**ac **o**ne **n**ode)

	Si le paramètre -pdbName n'est pas précisé la pdb daisy01 sera créée ainsi que
	son service pdbdaisy01.

	La règle de nommage étant :
	 * Nom de la pdb = nom du cdb || 01
	 * Nom du service = pdb || nom de la pdb

	Les bases sont créées avec l'option threaded_execution=true, pour se connecter
	avec le compte sys il faut donc utiliser la syntaxe : `sqlplus sys/Oracle12 as sysbda`

	Il en va de même pour rman & co.

	Les bases sont créées en 'archive log'

	Une fois le script terminé le statue de la base est affichée

	- exemple d'une base SINGLE :
	```
	# ==============================================================================
	# Database config :
	21h30> srvctl config database -db daisy
	Database unique name: DAISY
	Database name: DAISY
	Oracle home: /u01/app/oracle/12.1.0.2/dbhome_1
	Oracle user: oracle
	Spfile: +DATA/DAISY/PARAMETERFILE/spfile.259.916261895
	Password file:
	Domain:
	Start options: open
	Stop options: immediate
	Database role: PRIMARY
	Management policy: AUTOMATIC
	Disk Groups: FRA,DATA
	Services: pdbdaisy01
	OSDBA group:
	OSOPER group:
	Database instance: DAISY
	
	# ==============================================================================
	21h30> crsctl stat res ora.daisy.db -t
	--------------------------------------------------------------------------------
	Name           Target  State        Server                   State details
	--------------------------------------------------------------------------------
	Cluster Resources
	--------------------------------------------------------------------------------
	ora.daisy.db
	      1        ONLINE  ONLINE       srvdaisy01              Open,STABLE
	--------------------------------------------------------------------------------
	```

	Pour utiliser le compte grid depuis le compte oracle pas besoin de mot de passe :
	```
	oracle@srvdaisy01:DAISY:oracle> sugrid
	grid@srvdaisy01:+ASM:grid> asmcmd lsdg
	State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
	MOUNTED  EXTERN  N         512   4096  1048576     32752    27479                0           27479              0             N  DATA/
	MOUNTED  EXTERN  N         512   4096  1048576     32752    31117                0           31117              0             N  FRA/
	````

	- exemple d'une base RAC :
	```
	# ==============================================================================
	# Database config :
	00h33> srvctl config database -db daisy
	Database unique name: DAISY
	Database name: DAISY
	Oracle home: /u01/app/oracle/12.1.0.2/dbhome_1
	Oracle user: oracle
	Spfile: +DATA/DAISY/PARAMETERFILE/spfile.271.916272881
	Password file: +DATA/DAISY/PASSWORD/pwddaisy.256.916270231
	Domain:
	Start options: open
	Stop options: immediate
	Database role: PRIMARY
	Management policy: AUTOMATIC
	Server pools:
	Disk Groups: FRA,DATA
	Mount point paths:
	Services: pdbdaisy01
	Type: RAC
	Start concurrency:
	Stop concurrency:
	OSDBA group: dba
	OSOPER group: oper
	Database instances: DAISY1,DAISY2
	Configured nodes: srvdaisy01,srvdaisy02
	Database is administrator managed
	
	# ==============================================================================
	00h33> crsctl stat res ora.daisy.db -t
	--------------------------------------------------------------------------------
	Name           Target  State        Server                   State details
	--------------------------------------------------------------------------------
	Cluster Resources
	--------------------------------------------------------------------------------
	ora.daisy.db
	      1        ONLINE  ONLINE       srvdaisy01              Open,STABLE
	      2        ONLINE  ONLINE       srvdaisy02              Open,STABLE
	--------------------------------------------------------------------------------
	```

	```
	oracle@srvdaisy01:DAISY1:oracle> sugrid
	grid@srvdaisy01:+ASM1:grid> asmcmd lsdg
	State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
	MOUNTED  NORMAL  N         512   4096  1048576     18420    17689             6140            5774              0             Y  CRS/
	MOUNTED  EXTERN  N         512   4096  1048576     32752    26801                0           26801              0             N  DATA/
	MOUNTED  EXTERN  N         512   4096  1048576     32752    30560                0           30560              0             N  FRA/
	```

--------------------------------------------------------------------------------

License
-------

Copyright (©) 2016 Philippe Leroux - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
