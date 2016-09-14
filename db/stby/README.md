#	Création d'un dataguard.
  La standby sera en 'real time apply' et ouverte en lecture seule.

  **Note la FRA est grande mais pas infinie, mettre en place les backups RMAN !**

  **TODO** Tester la création d'un dataguard avec au moins 2 PDBs (risque au niveau des services)

##	Pré requis.
 - [Créer 2 serveurs, ex : srvmars01 & srvvenus01.](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/README.md)
 - [Créer une base sur le serveur mars.](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)
 
## Etablir les équivalences ssh entre les 2 serveurs pour le compte Oracle.
 - Sur le poste client aller dans le répertoire `~/plescripts/db/stby`

 - Etablir l'équivalence ssh entre les comptes oracle des 2 serveurs.

   Exécuter la commande :

   `./00_setup_equivalence.sh -server1=srvmars01 -server2=srvvenus01 -user1=oracle`

## Etat des lieux :
 - Initiallement la base est créées comme une SINGLE, les services sur la PDB mars01 est minimum :
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

   Le script de duplication est simple car les bases sont en 'Oracle Managed File' et
   sur ASM. Pas besoin de [db|log]_convert.

 * Services.

   Il y a 4 services par instance. Il y a 1 service pour les connexions OCI et 1
   service pour les connexions JAVA. Les 2 autres son leur correspondance pour la
   standby (accès en lecture seul).

   _Note :_ ils n'ont pas été testés.

 * Les swhitchover ont été testés et fonctionnent.

## Test du faileover
  [Description des étapes](https://github.com/PhilippeLeroux/plescripts/blob/master/db/stby/faileover.md)
 
##	Prochaine étape.
 L'observeur : sur K2 ??
