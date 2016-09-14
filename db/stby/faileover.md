## Exemple avec 2 serveurs srvmars01 et srvvenus01

* Serveur srvvenus01 :

	```
	oracle@srvvenus01:VENUS:oracle> crsctl stat res -t
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
	ora.venus.db
		  1        ONLINE  ONLINE       srvvenus01               Open,STABLE
	ora.venus.pdbvenus01_java.svc
		  1        ONLINE  ONLINE       srvvenus01               STABLE
	ora.venus.pdbvenus01_oci.svc
		  1        ONLINE  ONLINE       srvvenus01               STABLE
	ora.venus.pdbvenus01_stby_java.svc
		  1        OFFLINE OFFLINE                               STABLE
	ora.venus.pdbvenus01_stby_oci.svc
		  1        OFFLINE OFFLINE                               STABLE
	--------------------------------------------------------------------------------
	```
* Serveur srvmars01
	```
	oracle@srvmars01:MARS:oracle> crsctl stat res -t
	--------------------------------------------------------------------------------
	Name           Target  State        Server                   State details
	--------------------------------------------------------------------------------
	Local Resources
	--------------------------------------------------------------------------------
	ora.DATA.dg
				   ONLINE  ONLINE       srvmars01                STABLE
	ora.FRA.dg
				   ONLINE  ONLINE       srvmars01                STABLE
	ora.LISTENER.lsnr
				   ONLINE  ONLINE       srvmars01                STABLE
	ora.asm
				   ONLINE  ONLINE       srvmars01                Started,STABLE
	ora.ons
				   OFFLINE OFFLINE      srvmars01                STABLE
	--------------------------------------------------------------------------------
	Cluster Resources
	--------------------------------------------------------------------------------
	ora.cssd
		  1        ONLINE  ONLINE       srvmars01                STABLE
	ora.diskmon
		  1        OFFLINE OFFLINE                               STABLE
	ora.evmd
		  1        ONLINE  ONLINE       srvmars01                STABLE
	ora.mars.db
		  1        ONLINE  ONLINE       srvmars01                Open,Readonly,STABLE
	ora.mars.pdbvenus01_java.svc
		  1        OFFLINE OFFLINE                               STABLE
	ora.mars.pdbvenus01_oci.svc
		  1        OFFLINE OFFLINE                               STABLE
	ora.mars.pdbvenus01_stby_java.svc
		  1        ONLINE  ONLINE       srvmars01                STABLE
	ora.mars.pdbvenus01_stby_oci.svc
		  1        ONLINE  ONLINE       srvmars01                STABLE
	--------------------------------------------------------------------------------
	```

* Statut de la synchronisation et validation de la bascule.

	Se connecter sur le serveur srvmars01 et sourcer l'environnement de la base.

	```
	oracle@srvmars01:MARS:stby> ./show_dataguard_cfg.sh 
	# Running : ./show_dataguard_cfg.sh 
	# ===========================================================================================
	14h25> dgmgrl -silent -echo sys/Oracle12 'show configuration'

	Configuration - PRODCONF

	  Protection Mode: MaxPerformance
	  Members:
	  venus - Primary database
		mars  - Physical standby database 

	Fast-Start Failover: DISABLED

	Configuration Status:
	SUCCESS   (status updated 20 seconds ago)
																								  
	# ===========================================================================================
	14h25> dgmgrl -silent -echo sys/Oracle12 'show database venus'

	Database - venus

	  Role:               PRIMARY
	  Intended State:     TRANSPORT-ON
	  Instance(s):
		VENUS

	Database Status:
	SUCCESS

	14h25> dgmgrl -silent -echo sys/Oracle12 'validate database venus'

	  Database Role:    Primary database

	  Ready for Switchover:  Yes

	  Flashback Database Status:
		venus:  Off

	# ===========================================================================================
	14h25> dgmgrl -silent -echo sys/Oracle12 'show database mars'

	Database - mars

	  Role:               PHYSICAL STANDBY
	  Intended State:     APPLY-ON
	  Transport Lag:      0 seconds (computed 0 seconds ago)
	  Apply Lag:          0 seconds (computed 0 seconds ago)
	  Average Apply Rate: 24.00 KByte/s
	  Real Time Query:    ON
	  Instance(s):
		MARS

	Database Status:
	SUCCESS

	14h25> dgmgrl -silent -echo sys/Oracle12 'validate database mars'

	  Database Role:     Physical standby database
	  Primary Database:  venus

	  Ready for Switchover:  Yes
	  Ready for Failover:    Yes (Primary Running)

	  Flashback Database Status:
		venus:  Off
		mars:   Off
	```

	Donc le faileover devrait se passer sans problème.

## Provoquer le crash du serveur primaire venus.

* Faire un poweroff du serveur srvvenus01 et afficher de nouveau la configuration.

	(le poweroff de VBox tue le serveur)

	```
	oracle@srvmars01:MARS:stby> ./show_dataguard_cfg.sh 
	# Running : ./show_dataguard_cfg.sh 
	# ===========================================================================================
	14h31> dgmgrl -silent -echo sys/Oracle12 'show configuration'

	Configuration - PRODCONF

	  Protection Mode: MaxPerformance
	  Members:
	  venus - Primary database
		Error: ORA-12543: TNS:destination host unreachable

		mars  - Physical standby database 

	Fast-Start Failover: DISABLED

	Configuration Status:
	ERROR   (status updated 0 seconds ago)

	# ===========================================================================================
	14h32> dgmgrl -silent -echo sys/Oracle12 'show database venus'

	Database - venus

	  Role:               PRIMARY
	  Intended State:     TRANSPORT-ON
	  Instance(s):
		VENUS

	Database Status:
	DGM-17016: failed to retrieve status for database "venus"
	ORA-12543: TNS:destination host unreachable
	ORA-16625: cannot reach database "venus"

	14h32> dgmgrl -silent -echo sys/Oracle12 'validate database venus'
	Error: ORA-12543: TNS:destination host unreachable
	Error: ORA-16625: cannot reach database "venus"

	# ===========================================================================================
	14h32> dgmgrl -silent -echo sys/Oracle12 'show database mars'

	Database - mars

	  Role:               PHYSICAL STANDBY
	  Intended State:     APPLY-ON
	  Transport Lag:      0 seconds (computed 255 seconds ago)
	  Apply Lag:          0 seconds (computed 255 seconds ago)
	  Average Apply Rate: 10.00 KByte/s
	  Real Time Query:    ON
	  Instance(s):
		MARS

	  Database Warning(s):
		ORA-16857: standby disconnected from redo source for longer than specified threshold

	Database Status:
	WARNING

	14h32> dgmgrl -silent -echo sys/Oracle12 'validate database mars'

	  Database Role:     Physical standby database
	  Primary Database:  venus
		Warning: primary database was not reachable

	  Ready for Switchover:  No
	  Ready for Failover:    Yes (Primary Not Running)

	  Temporary Tablespace File Information:
		venus TEMP Files:  Unknown
		mars TEMP Files:   3

	  Flashback Database Status:
		venus:  Unknown
		mars:   Off

	  Data file Online Move in Progress:
		venus:  Unknown
		mars:   No

	  Transport-Related Information:
		Transport On:      No
		Gap Status:        Unknown
		Transport Lag:     0 seconds (computed 256 seconds ago)
		Transport Status:  Success

	  Log Files Cleared:
		venus Standby Redo Log Files:  Unknown
		mars Online Redo Log Files:    Unknown
		mars Standby Redo Log Files:   Unknown
	```

* failover : se connecter avec le dataguard manager
	```
	DGMGRL> connect sys/Oracle12
	Connected as SYSDBA.
	DGMGRL> failover to mars;
	Performing failover NOW, please wait...
	Failover succeeded, new primary is "mars"
	```

* Vérification du statut de la base et des services.
	```
	oracle@srvmars01:MARS:oracle> srvctl status database -db mars
	Database is running.
	oracle@srvmars01:MARS:oracle> srvctl status service -db mars
	Service pdbVENUS01_java is running
	Service pdbVENUS01_oci is running
	Service pdbVENUS01_stby_java is not running.
	Service pdbVENUS01_stby_oci is not running.
	oracle@srvmars01:MARS:stby> ./show_dataguard_cfg.sh 
	# Running : ./show_dataguard_cfg.sh 
	# ===========================================================================================
	14h39> dgmgrl -silent -echo sys/Oracle12 'show configuration'

	Configuration - PRODCONF

	  Protection Mode: MaxPerformance
	  Members:
	  mars  - Primary database
		venus - Physical standby database (disabled)
		  ORA-16661: the standby database needs to be reinstated

	Fast-Start Failover: DISABLED

	Configuration Status:
	SUCCESS   (status updated 32 seconds ago)

	# ===========================================================================================
	14h39> dgmgrl -silent -echo sys/Oracle12 'show database mars'

	Database - mars

	  Role:               PRIMARY
	  Intended State:     TRANSPORT-ON
	  Instance(s):
		MARS

	Database Status:
	SUCCESS

	14h39> dgmgrl -silent -echo sys/Oracle12 'validate database mars'

	  Database Role:    Primary database

	  Ready for Switchover:  Yes

	  Flashback Database Status:
		mars:  Off

	# ===========================================================================================
	14h39> dgmgrl -silent -echo sys/Oracle12 'show database venus'

	Database - venus

	  Role:               PHYSICAL STANDBY
	  Intended State:     APPLY-ON
	  Transport Lag:      (unknown)
	  Apply Lag:          (unknown)
	  Average Apply Rate: (unknown)
	  Real Time Query:    OFF
	  Instance(s):
		VENUS

	Database Status:
	ORA-16661: the standby database needs to be reinstated

	14h39> dgmgrl -silent -echo sys/Oracle12 'validate database venus'
	Error: ORA-16548: database not enabled
	```

	Le reinstate ne fonctionnera pas, le flashback n'est pas activé.

	Prochaines étapes détruire la base venus et la recréer.

## Destruction de la base venus
* Démarrer le serveur srvvenus01 et se connecter root.
* Statut de la base :
	```
	[root@srvvenus01 ~]# crsctl stat res -t
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
	ora.venus.db
		  1        ONLINE  INTERMEDIATE srvvenus01               Mounted (Closed),STA
																 BLE
	ora.venus.pdbvenus01_java.svc
		  1        ONLINE  OFFLINE                               STABLE
	ora.venus.pdbvenus01_oci.svc
		  1        ONLINE  OFFLINE                               STABLE
	ora.venus.pdbvenus01_stby_java.svc
		  1        OFFLINE OFFLINE                               STABLE
	ora.venus.pdbvenus01_stby_oci.svc
		  1        OFFLINE OFFLINE                               STABLE
	--------------------------------------------------------------------------------
	```

* Destruction de la base avec le compte root.

	Le script `remove_all_files_for_db.sh` détruit toute trace d'une base.

	```
	[root@srvvenus01 ~]# cd plescripts/db
	[root@srvvenus01 db]# ./remove_all_files_for_db.sh -db=venus
	11h18> srvctl stop database -db VENUS
	11h18> srvctl remove database -db venus<<<y
	Remove the database venus? (y/[n]) 11h18> kill -9
	kill: usage: kill [-s sigspec | -n signum | -sigspec] pid | jobspec ... or kill -l [sigspec]
	< kill return 1
	# ===========================================================================================
	# Remove all Oracle files on node srvvenus01
	11h18> su - oracle -c 'rm -rf $ORACLE_BASE/cfgtoollogs/dbca/VENUS*'
	11h18> su - oracle -c 'rm -rf $ORACLE_BASE/diag/rdbms/venus'
	11h18> su - oracle -c 'rm -rf $ORACLE_HOME/dbs/*VENUS*'
	11h18> su - oracle -c 'rm -rf $ORACLE_BASE/admin/VENUS'

	11h18> sed '/VENUS[_|0-9].*/d' /etc/oratab > /tmp/oratab
	11h18> cat /tmp/oratab > /etc/oratab && rm /tmp/oratab

	# ===========================================================================================
	# Remove database files from ASM
	11h18> su - grid -c "asmcmd rm -rf DATA/VENUS"
	11h18> su - grid -c "asmcmd rm -rf FRA/VENUS"

	# ===========================================================================================
	# done.
	```

	Status du GI.
	```
	[root@srvvenus01 db]# crsctl stat res -t
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

## Recréation de la standby.
* Se connecter sur le serveur de la base primaire srvmars01 avec le compte Oracle.

	Le script `create_dataguard.sh` avec la paramètre -skip_primary_cfg permet
	de refaire une standby.

	```
	oracle@srvmars01:MARS:~> cd db/stby/
	oracle@srvmars01:MARS:stby> ./create_dataguard.sh -standby=venus \
	 -standby_host=srvvenus01 -skip_primary_cfg
	[....]
	# ===========================================================================================
	15h03> ~/plescripts/db/stby/show_dataguard_cfg.sh
	# Running : /home/oracle/plescripts/db/stby/show_dataguard_cfg.sh 
	# =============================================================================
	15h03> dgmgrl -silent -echo sys/Oracle12 'show configuration'

	Configuration - PRODCONF

	  Protection Mode: MaxPerformance
	  Members:
	  mars  - Primary database
		venus - Physical standby database 

	Fast-Start Failover: DISABLED

	Configuration Status:
	SUCCESS   (status updated 20 seconds ago)

	# =============================================================================
	15h03> dgmgrl -silent -echo sys/Oracle12 'show database mars'

	Database - mars

	  Role:               PRIMARY
	  Intended State:     TRANSPORT-ON
	  Instance(s):
		MARS

	Database Status:
	SUCCESS

	15h03> dgmgrl -silent -echo sys/Oracle12 'validate database mars'

	  Database Role:    Primary database

	  Ready for Switchover:  Yes

	  Flashback Database Status:
		mars:  Off

	# =============================================================================
	15h03> dgmgrl -silent -echo sys/Oracle12 'show database venus'

	Database - venus

	  Role:               PHYSICAL STANDBY
	  Intended State:     APPLY-ON
	  Transport Lag:      0 seconds (computed 1 second ago)
	  Apply Lag:          0 seconds (computed 1 second ago)
	  Average Apply Rate: 2.00 KByte/s
	  Real Time Query:    ON
	  Instance(s):
		VENUS

	Database Status:
	SUCCESS

	15h03> dgmgrl -silent -echo sys/Oracle12 'validate database venus'

	  Database Role:     Physical standby database
	  Primary Database:  mars

	  Ready for Switchover:  Yes
	  Ready for Failover:    Yes (Primary Running)

	  Flashback Database Status:
		mars:   Off
		venus:  Off

	# ./create_dataguard.sh 8mn13s
	```
