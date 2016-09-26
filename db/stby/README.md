#	Création d'un dataguard.
  La standby sera en 'real time apply' et ouverte en lecture seule.

##	Pré requis.
 - [Créer 2 serveurs, ex : srvmars01 & srvvenus01.](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/README.md)

   **Important** : Ne pas exécuter le second ./define_new_server.sh tant que le premier ./clone_master.sh n'est pas finie.

 - [Créer une base sur le serveur mars.](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)

## Etablir les équivalences ssh entre les 2 serveurs pour le compte Oracle.
 - Sur le poste client aller dans le répertoire `~/plescripts/db/stby`

 - Etablir l'équivalence ssh entre les comptes oracle des 2 serveurs.

   Exécuter la commande :

   `./00_setup_equivalence.sh -server1=srvmars01 -server2=srvvenus01 -user1=oracle`

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

##	Création de la dataguard.
 - Se connecter avec le compte oracle sur le serveur 'srvmars01' et charger l'environnement de la base.

 - Exécuter le script :
	```
	oracle@srvmars01:MARS:oracle> cd db/stby/
	oracle@srvmars01:MARS:stby> ./create_dataguard.sh -standby=venus -standby_host=srvvenus01
	```

## Description du script : `create_dataguard.sh`
 * Configuration du réseau :
   * Mise à jour du fichier tnsnames.ora pour que les bases puissent se joindre.
   * Ajout d'une entrée statique dans le listener sur les 2 serveurs pour le duplicate.

 * Avant de lancer le duplicate :
   * Copie du fichier password vers la standby.
   * Création du répertoire adump sur la standby.

 * Duplication.

   Le script de duplication est simple car les bases sont en 'Oracle Managed File'.

 * Services.

   Il y a 4 services par instance. Il y a 1 service pour les connexions OCI et 1
   service pour les connexions JAVA. Les 2 autres ont leurs correspondances pour la
   standby (accès en lecture seul).

   _Note :_ ils n'ont pas été testés.

 * Le swhitchover est opérationnel.

## Faileover
 [Effectuer un faileover](https://github.com/PhilippeLeroux/plescripts/wiki/faileover)

##	Prochaine étape.
 L'observeur : sur K2 ??

## Test : Est ce que la création du PDB est automatiquement répercuté sur la stby.
 * Status :

	```
	oracle@srvuranus01:URANUS:12c> dgmgrl -silent sys/Oracle12 'show configuration'

	Configuration - DGCONF

	  Protection Mode: MaxPerformance
	  Members:
	  uranus - Primary database
		venus  - Physical standby database

	Fast-Start Failover: DISABLED

	Configuration Status:
	SUCCESS   (status updated 16 seconds ago)
	```

 * Liste des PDBs :

	```
	SQL> @containers.sql

	Instance   PDB name   Open mode  Open time      Total size (Gb) RECOVERY RES
	---------- ---------- ---------- -------------- --------------- -------- ---
	URANUS     CDB$ROOT   READ WRITE 16/09/25 19:09               0 ENABLED  NO
	URANUS     VENUS01    READ WRITE 16/09/25 19:09               1 ENABLED  NO
	```

 * Création du PDB VENUS02

	```
	SQL> create pluggable database VENUS02 from VENUS01;

	Pluggable database created.

	SQL> @containers.sql

	Instance   PDB name   Open mode  Open time      Total size (Gb) RECOVERY RES
	---------- ---------- ---------- -------------- --------------- -------- ---
	URANUS     CDB$ROOT   READ WRITE 16/09/25 19:09               0 ENABLED  NO
	URANUS     VENUS01    READ WRITE 16/09/25 19:09               1 ENABLED  NO
	URANUS     VENUS02    MOUNTED    16/09/25 19:20               0 ENABLED
	```

 * Connection sur la base VENUS :
	```
	SQL> @containers.sql

	Instance   PDB name   Open mode  Open time      Total size (Gb) RECOVERY RES
	---------- ---------- ---------- -------------- --------------- -------- ---
	VENUS      CDB$ROOT   READ ONLY  16/09/25 19:12               0 ENABLED  NO
	VENUS      VENUS01    READ ONLY  16/09/25 19:12               0 ENABLED  NO
	VENUS      VENUS02    MOUNTED                                 0 ENABLED
	```

 * Ajout des services

 Services primaire :

	```
	oracle@srvuranus01:URANUS:12c> ~/plescripts/db/create_srv_for_single_db.sh \
	> -db=uranus -pdbName=VENUS02 -role=primary
	# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=uranus -pdbName=VENUS02 -prefixService=pdbVENUS02 -role=primary
	# ============================================================================================
	# create service pdbVENUS02_oci on pdb VENUS02 (db = uranus).

	08h29> srvctl                                   \
			   add service -service pdbVENUS02_oci  \
				   -pdb VENUS02 -db uranus          \
				   -role           primary          \
				   -policy         automatic        \
				   -failovertype   select           \
				   -failovermethod basic            \
				   -failoverretry  3                \
				   -failoverdelay  60               \
				   -clbgoal        long             \
				   -rlbgoal        throughput

	08h29> srvctl start service -service pdbVENUS02_oci -db uranus

	# ============================================================================================
	# create service pdbVENUS02_java on pdb VENUS02 (db = uranus)

	08h30> srvctl                                    \
			   add service -service pdbVENUS02_java  \
				   -pdb VENUS02 -db uranus           \
				   -role           primary           \
				   -policy         automatic         \
				   -failovertype   select            \
				   -failovermethod basic             \
				   -failoverretry  3                 \
				   -failoverdelay  60                \
				   -clbgoal        long              \
				   -rlbgoal        throughput

	08h30> srvctl start service -service pdbVENUS02_java -db uranus

	oracle@srvuranus01:URANUS:12c>
	```

 Services standby :

	```
	oracle@srvuranus01:URANUS:12c> ~/plescripts/db/create_srv_for_single_db.sh \
	> -db=uranus -pdbName=VENUS02 -role=physical_standby \
	> -start=no
	# Running : /home/oracle/plescripts/db/create_srv_for_single_db.sh -db=uranus -pdbName=VENUS02 -prefixService=pdbVENUS02_stby -role=physical_standby -start=no
	# ============================================================================================
	# create service pdbVENUS02_stby_oci on pdb VENUS02 (db = uranus).

	08h32> srvctl                                        \
			   add service -service pdbVENUS02_stby_oci  \
				   -pdb VENUS02 -db uranus               \
				   -role           physical_standby      \
				   -policy         automatic             \
				   -failovertype   select                \
				   -failovermethod basic                 \
				   -failoverretry  3                     \
				   -failoverdelay  60                    \
				   -clbgoal        long                  \
				   -rlbgoal        throughput

	# ============================================================================================
	# create service pdbVENUS02_stby_java on pdb VENUS02 (db = uranus)

	08h32> srvctl                                         \
			   add service -service pdbVENUS02_stby_java  \
				   -pdb VENUS02 -db uranus                \
				   -role           physical_standby       \
				   -policy         automatic              \
				   -failovertype   select                 \
				   -failovermethod basic                  \
				   -failoverretry  3                      \
				   -failoverdelay  60                     \
				   -clbgoal        long                   \
				   -rlbgoal        throughput
	```
