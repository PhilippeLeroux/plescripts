Table of Contents
=================

 * [Création d'un dataguard.](#création-dun-dataguard)
    * [Pré requis.](#pré-requis)
    * [Etablir les équivalences ssh entre les 2 serveurs pour le compte Oracle.](#etablir-les-équivalences-ssh-entre-les-2-serveurs-pour-le-compte-oracle)
    * [Etat des lieux :](#etat-des-lieux-)
    * [Création de la dataguard.](#création-de-la-dataguard)
 * [Description du script : create_dataguard.sh](#description-du-script--create_dataguardsh)
 * [Le swhitchover est opérationnel.](#le-swhitchover-est-opérationnel)
 * [Le swhitchover est opérationnel.](#le-swhitchover-est-opérationnel-1)
 * [Faileover](#faileover)
 * [Prochaine étape.](#prochaine-étape)

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

## Description du script : `create_dataguard.sh`
 * Configuration du réseau :
   * Mise à jour du fichier tnsnames.ora pour que les bases puissent se joindre.
   * Ajout d'une entrée statique dans le listener sur les 2 serveurs pour le duplicate.

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

 * Services.

   Il y a 4 services par instance. Il y a 1 service pour les connexions OCI et 1
   service pour les connexions JAVA. Les 2 autres ont leurs correspondances pour la
   standby (accès en lecture seule).

   Aucun des services de la standby ne sont démarés

 * Configuration du Data Guard broker
   * Les 2 instances sont ajoutées.
   * La base standby est ouverte en RO, les services nécessaires sont donc démarrés.

--------------------------------------------------------------------------------

# Le swhitchover est opérationnel.

  Rien de spécial à dire sauf qu'il est testé.

--------------------------------------------------------------------------------

# Faileover
 [Effectuer un faileover](https://github.com/PhilippeLeroux/plescripts/wiki/faileover)

--------------------------------------------------------------------------------

#	Prochaine étape.
 * L'observer : sur K2 ??
 * Tester si l'ajout d'un 3e standby peut se faire sans modification du script.

--------------------------------------------------------------------------------
