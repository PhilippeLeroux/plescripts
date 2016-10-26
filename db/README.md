Table of Contents
=================

  * [Création d'une base de donnée.](#création-dune-base-de-donnée)
  * [Description des scripts liées à la gestion des services.](#description-des-scripts-liées-à-la-gestion-des-services)
    * [Création de services et alias TNS](#Création-de-services-et-alias-TNS)
    * [Suppression de services et alias TNS](#suppression-de-services-et-alias-tns)
    * [Scripts pour la gestion des alias TNS](#scripts-pour-la-gestion-des-alias-tns)

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

	```
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
	
	La configuration de la base SINGLE ou RAC est détectée automatiquement. 

	Les bases sont créées avec l'option threaded_execution=true, pour se connecter
	avec le compte sys il faut donc utiliser la syntaxe : `sqlplus sys/Oracle12 as sysbda`

	Paramètres utiles :
	 - -db_type=RACONENODE, crée un RAC One Node et le service ron_'nom_du_serveur ou est crée la base' (ron = rac one node)

	 - -pdbName= permet de nommer la PDB créée.

		Sans ce paramètre la règle de nommage est :
		 * Nom de la pdb = nom du cdb || 01
		 * Nom du service = pdb || nom de la pdb

	 - -policyManaged permet, dans le cas d'un RAC, d'utiliser des services 'Policy Managed'

	 - -serverPoolName= dans le cas d'un RAC 'Policy Managed' permet de spécifier
	 le nom du 'pool' qui par défaut est `poolAllNodes`.

	   L'utilisation de ce paramètre active automatiquement `-policyManaged`

	Une sauvegarde est lancée avec rman une fois la base créée.

	Une fois le script terminé le statue de la base est affichée :

	- exemple d'une base SINGLE :

		```c
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

		Afficher les DGs :

		```c
		oracle@srvdaisy01:DAISY:oracle> sugrid
		grid@srvdaisy01:+ASM:grid> asmcmd lsdg
		State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
		MOUNTED  EXTERN  N         512   4096  1048576     32752    27479                0           27479              0             N  DATA/
		MOUNTED  EXTERN  N         512   4096  1048576     32752    31117                0           31117              0             N  FRA/
		````

	- exemple d'une base RAC :

		```c
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

		Afficher les DGs :

		```c
		oracle@srvdaisy01:DAISY1:oracle> sugrid
		grid@srvdaisy01:+ASM1:grid> asmcmd lsdg
		State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
		MOUNTED  NORMAL  N         512   4096  1048576     18420    17689             6140            5774              0             Y  CRS/
		MOUNTED  EXTERN  N         512   4096  1048576     32752    26801                0           26801              0             N  DATA/
		MOUNTED  EXTERN  N         512   4096  1048576     32752    30560                0           30560              0             N  FRA/
		```

--------------------------------------------------------------------------------

###	Description des scripts liées à la gestion des services.

#### Création de services et alias TNS
 * create_srv_for_rac_db.sh : crée des services pour un RAC

 * create_srv_for_single_db.sh : crée des services pour une mono instance.

	Le script va créer un service pour les connexions OCI et un service pour les connexions Java.
	Pour chaque service OCI un alias TNS est ajouté dans tnsnames.ora, le service et
	l'alias ont le même nom.

 * add_srv_for_dataguard.sh : crée des services pour une base en dataguard.

	L'équivalence ssh entre les comptes oracle doit être faite.

	4 services sont créés sur les 2 bases du dataguard :
	 * *_oci et *_java qui ont le rôle 'primary'
	 * *_stby_oci et *_stby_java qui ont le rôle 'standby'

	Des alias TNS sont créés pour les services de type OCI.

	Ce script n'est pas valable si la bases sont en RAC.

#### Suppression de services et alias TNS
 * drop_all_services.sh : supprime tous les services existant et les alias TNS associées.

 * drop_all_services_for_pdb.sh : supprime tous les services d'un PDB et les alias TNS associées.

 * drop_service.sh : supprime un service et son alias TNS s'il existe.

#### Scripts pour la gestion des alias TNS
 * add_tns_alias.sh
 * delete_tns_alias.sh

Ces scripts sont utilisés par les scripts de gestion des services.

[Exemples](https://github.com/PhilippeLeroux/plescripts/wiki/Création-d'un-PDB) d'utilisation lors de la création d'un noveau PDB.
