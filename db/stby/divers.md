Table of Contents
=================

 * [Test : Est ce que la création du PDB est automatiquement répercuté sur la stby.](#test--est-ce-que-la-création-du-pdb-est-automatiquement-répercuté-sur-la-stby)
 * [Activation du flashback :](#activation-du-flashback-)
   * [Test #1](#test-1)
   * [Test #2](#test-2)

--------------------------------------------------------------------------------

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

	Pas de problèmes !

 * Ajout des services

    * Primary :

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

    * Standby :

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

--------------------------------------------------------------------------------

##	Activation du flashback :
### Test #1
 * Activer sur la primaire ne se repercute pas sur la secondaire.
 * Exécution de pleins de switch log : ne se repercute pas sur la secondaire.
 * Arrêt de la primaire et de la secondaire puis démarrage :  ne se repercute pas sur la secondaire.

### Test #2
 * Destruction de la stby
 * Suppression de la config de la primaire
 * Re-création de la stby

**Le flashback n'est jamais propagé !**
Adaptation du script : create_dataguard.sh
