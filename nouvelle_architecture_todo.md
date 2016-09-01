# Etude d'impacte :

## global.cfg
	if_net_name
		garder eth2 n'existe que sur K2

	if_priv_name :
		renomer en if_iscsi_name
		conserver eth1
		réseau 10.10.10/24

	if_rac_name (nouvelle interface) :
		vaut eth2
		réseau 20.20.20/24

## Impactes :

	1. Renommer if_priv_name en if_iscsi_name
	git mettra en évidence l'ensemble des fichiers/scripts impactés.

	2. Changer le réseau de if_iscsi_name ==> global.cfg uniquement

	A ce stade l'interco des disques est opérationnel et pas de scripts à adapter.
	(Confiance de 99.999999999999%)

	3. Scripts à modifier
		3.1 Ajout les variables nécessaires pour if_rac* dans global.cfg

		3.2 Le script `install_grid.sh` est à modifier.
			Remplacer tous les if_priv_name par if_rac_name.

		3.3 Les scripts de création de VMs
			Ce sont peut-être eux les plus hards.
			Demain je regarge en détails.

## Résumé ifaces :
	K2 :
		eth0	public
		eth1	privée	ISCSI interco
		eth2	internet

	Noeud RAC :
		eth0	public
		eth1	privée	ISCSI interco
		eth2	privée	RAC interco

## Après :
	Mettre à jour le fichier schema_reseau.txt dans le wiki

## GO :
Renommage fait, liste des actions à faire sur les fichiers modifiés.

        modifié :         configure_network/setup_iface_and_hostename.sh
			renomer ts les if_iscsi_* en if_rac_*

        modifié :         database_servers/define_new_server.sh
			if_iscsi_network -> if_rac_network

        modifié :         database_servers/install_grid.sh
			renomer ts les if_iscsi_* en if_rac_*

        modifié :         database_servers/revert_to_master.sh
			if_iscsi_network -> if_rac_network ??

        modifié :         global.cfg

        modifié :         nouvelle_architecture_todo.md

        modifié :         patch/force_if_speed.sh	SUPPRIMER LE FICHIER

        modifié :         setup_first_vms/03_setup_master_vm.sh
			Rien à faire, ce script crée 2 ifaces.

        modifié :         setup_first_vms/vbox_scripts/02_create_infra_vm.sh
			Rién à faire.

        modifié :         stats/ifstats.sh

Maintenant il faut créer l'iface RAC !
	-	Ajouter la carte sur la VM
			--> 03_create_master_vm.sh

	-	Configurer la carte sur l'OS.
			--> setup_iface_and_hostename.sh
		Note : ce script est de plus en plus pourri, il date de la version 1, trop
		de hacks ont été faits et il est devenu difficile d'interprétation entre
		anciennes règles et nouvelles.

## Teste clonage :(

Constatation :

* mettre à jour le fichier show_info_server.sh	FAIT !

* Bug #1 :
```
# ==========================================================================================
# Configure interface eth2 :
* File '/etc/sysconfig/network-scripts/ifcfg-eth2' not exists.
* Call function update_value
Connection to nfsorclmaster closed.
* ssh return 1
```
Raison la NIC n'a pas été créée, pourquoi ??
	Elle est créée lors de la construction du master, il faut donc que je l'ajoute
	manuellement.

* setup_first_vms/03_setup_master_vm.sh
	Voir TODO configuration inutile ici à virer.

* 2nd lancement du clonage : l'IP d'eth2 est 20.20.20. erreur dans le nom de la variable.
  Ca semble être le seul bug.
  Corriger manuellement sur le premier noeud, je lance le clonage du noeud #2

* RAS : installation du grid et BOUM !!!!!!!!!!!
	Erreur fatal et biensur la log il l'efface.
	Je relance l'installation sans rien changer et ca marche !
	OK :
	```
	11h57> ssh grid@srvtest01 ". ~/.profile; crsctl stat res -t"
	--------------------------------------------------------------------------------
	Name           Target  State        Server                   State details       
	--------------------------------------------------------------------------------
	Local Resources
	--------------------------------------------------------------------------------
	ora.CRS.dg
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	ora.DATA.dg
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	ora.FRA.dg
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	ora.LISTENER.lsnr
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	ora.asm
				   ONLINE  ONLINE       srvtest01                Started,STABLE
				   ONLINE  ONLINE       srvtest02                Started,STABLE
	ora.net1.network
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	ora.ons
				   ONLINE  ONLINE       srvtest01                STABLE
				   ONLINE  ONLINE       srvtest02                STABLE
	--------------------------------------------------------------------------------
	Cluster Resources
	--------------------------------------------------------------------------------
	ora.LISTENER_SCAN1.lsnr
		  1        ONLINE  ONLINE       srvtest02                STABLE
	ora.LISTENER_SCAN2.lsnr
		  1        ONLINE  ONLINE       srvtest02                STABLE
	ora.LISTENER_SCAN3.lsnr
		  1        ONLINE  ONLINE       srvtest01                STABLE
	ora.MGMTLSNR
		  1        OFFLINE OFFLINE                               STABLE
	ora.cvu
		  1        OFFLINE OFFLINE                               STABLE
	ora.oc4j
		  1        OFFLINE OFFLINE                               STABLE
	ora.scan1.vip
		  1        ONLINE  ONLINE       srvtest02                STABLE
	ora.scan2.vip
		  1        ONLINE  ONLINE       srvtest02                STABLE
	ora.scan3.vip
		  1        ONLINE  ONLINE       srvtest01                STABLE
	ora.srvtest01.vip
		  1        ONLINE  ONLINE       srvtest01                STABLE
	ora.srvtest02.vip
		  1        ONLINE  ONLINE       srvtest02                STABLE
	--------------------------------------------------------------------------------

	# Script : 30mn57s

	# The Oracle software can be installed.
	# ./install_oracle.sh -db=test
	```

	La bonne iface est utilisée :
	```
	[root@srvtest01 ~]# oifcfg getif
	eth0  192.170.100.0  global  public
	eth2  20.20.20.0  global  cluster_interconnect
	```

* Installation d'Oracle : RAS

* Création de la base : KO mais pas après les manips :
```
12h43> ~/plescripts/db/create_service_for_policy_managed.sh -db=TEST -pdbName=pdbtest01 -prefixService=pdbtest0101 -poolName=poolAllNodes
# Running : /home/oracle/plescripts/db/create_service_for_policy_managed.sh -db=TEST -pdbName=pdbtest01 -prefixService=pdbtest0101 -poolName=poolAllNodes
# =============================================================================
< Les services sont créées à partir de notes rapides.
< J'ai hacké pour que les services soient créées.
< Le but principal étant de poser un mémo
< Donc ils sont foireux et à adapter....

# =============================================================================
# create service pdbtest0101_oci on pdb pdbtest01 (db = TEST) attached to pool poolAllNodes

12h43> srvctl                                                    \
           add service -service pdbtest0101_oci                  \
               -pdb pdbtest01 -db TEST -serverpool poolAllNodes  \
               -cardinality uniform                              \
               -policy automatic                                 \
               -failovertype session                             \
               -failovermethod basic                             \
               -clbgoal long                                     \
               -rlbgoal throughput

12h43> srvctl start service -service pdbtest0101_oci -db TEST
```

Dans l'alert log : ora 65011 :
```
oracle@srvtest01:TEST_1:oracle> oerr ora 65011
65011, 00000, "Pluggable database %s does not exist."
// *Cause:  User attempted to specify a pluggable database
//          that does not exist.
// *Action: Check DBA_PDBS to see if it exists.
//
```
La commande start service a durée 10mn !

BUG : permière commande `-pdb pdbtest01` c'est `-pdb test01`

Erreur corrigée dans db/create_db.sh qui passait de mauvais paramètre au script
db/create_service_for_policy_managed.sh
