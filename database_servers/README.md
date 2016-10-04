### Objectif des scripts

Le but de ces scripts et de créer une infrastructure complète avec un minimum
d'interventions

Toutes les actions nécessaires sur K2 sont scriptées et transparentes :
- Le DNS est mis à jour.
- Le SAN est mis à jour, si nécessaire.
- Les horloges des serveurs synchronisées sur la même source.
- Les disques sont attachés via oracleasm.

La VM master sera clonée afin d'éviter d'installer l'OS à chaque fois.

**Note** : Tous les scripts sont exécutés depuis le poste client.

### Création de nouveaux serveurs :

Se postionner dans le répertoire `cd ~/plescripts/database_servers`

1.	Définir le serveur :

	Création d'un serveur standalone : `./define_new_server.sh -db=daisy`

	Création d'un RAC 2 nœuds : `./define_new_server.sh -db=daisy -max_nodes=2`

	**Note** Par défaut les disques sont créés sur VBox, pour créer les disques
	sur le SAN utiliser l'option `-luns_hosted_by=san`

	Un nouveau répertoire nommé daisy est créée contenant les fichiers décrivant
	le paramétrage du ou des serveurs.

	Par défaut les DGs DATA et FRA ont une taille de 24Gb chacun, la taille
	peut être changée à l'aide du paramètre -size_dg_gb

	Dans le cas d'un serveur standalone sont créées :

		1 serveur nommé  :	srvdaisy01
		8 disques nommés :	S1DISKDAISY01,S1DISKDAISY02,..., S1DISKDAISY08

	Dans le cas d'un RAC 2 nœuds on a un serveur de plus srvdaisy02 et 3 disques
	supplémentaires pour le CRS

2.	Clonage des VMs

	_Remarque :_  Le script `~/plescripts/yum/update_master.sh` met à jour les
	RPMs du master ce qui fait gagner du temps en particulier pour les RACs.

	Cloner un serveur standalone : `./clone_master.sh -db=daisy`

	Cloner le nœud d'un RAC      : `./clone_master.sh -db=daisy -node=1`

	Pour un RAC exécuter clone_master.sh autant de fois qu'il y a de noeuds en
	changeant le n° du nœud à chaque fois.

	Actions effectuées par le script :

	* Clone la VM master.
	* Renomme le serveur.
	* Configuration du réseau.
	* Création des disques.
	* Création des comptes oracle & grid.
	* Application des pré-requis Oracle.
	* Établie les connections ssh sans mot de passe entre le poste client et
	le serveur avec les comptes root, grid et oracle.

	Le compte oracle est configuré pour se connecter grid sans mot de passe via
	l'alias sugrid.

	Visualiser la configuration du DNS et du SAN.
	```
	ssh root@K2 plescripts/dns/show_dns.sh
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# Server             | ip
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	# kangs              | 192.170.100.1
	# orclmaster         | 192.170.100.2
	# K2                 | 192.170.100.5
	# srvdaisy01         | 192.170.100.11
	# srvdaisy01-vip     | 192.170.100.12
	# srvdaisy02         | 192.170.100.13
	# srvdaisy02-vip     | 192.170.100.14
	# daisy-scan         | 192.170.100.15
	# daisy-scan         | 192.170.100.16
	# daisy-scan         | 192.170.100.17
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	ssh -t root@K2 plescripts/san/show_db_info.sh -db=daisy
	# RAC cluster 2 nodes.
	# LUNs for daisy :
	12h29> targetcli ls /iscsi/iqn.1970-05.com.srvdaisy:01/tpg1/acls/iqn.1970-05.com.srvdaisy:01
	o- iqn.1970-05.com.srvdaisy:01 ................................................ [Mapped LUNs: 11]
	  o- mapped_lun1 .............................................. [lun1 block/asm01_lvdaisy01 (rw)]
	  o- mapped_lun2 .............................................. [lun2 block/asm01_lvdaisy02 (rw)]
	  o- mapped_lun3 .............................................. [lun3 block/asm01_lvdaisy03 (rw)]
	  o- mapped_lun4 .............................................. [lun4 block/asm01_lvdaisy04 (rw)]
	  o- mapped_lun5 .............................................. [lun5 block/asm01_lvdaisy05 (rw)]
	  o- mapped_lun6 .............................................. [lun6 block/asm01_lvdaisy06 (rw)]
	  o- mapped_lun7 .............................................. [lun7 block/asm01_lvdaisy07 (rw)]
	  o- mapped_lun8 .............................................. [lun8 block/asm01_lvdaisy08 (rw)]
	  o- mapped_lun9 .............................................. [lun9 block/asm01_lvdaisy09 (rw)]
	  o- mapped_lun10 ............................................ [lun10 block/asm01_lvdaisy10 (rw)]
	  o- mapped_lun11 ............................................ [lun11 block/asm01_lvdaisy11 (rw)]

	12h29> targetcli ls /iscsi/iqn.1970-05.com.srvdaisy:02/tpg1/acls/iqn.1970-05.com.srvdaisy:02
	o- iqn.1970-05.com.srvdaisy:02 ................................................ [Mapped LUNs: 11]
	  o- mapped_lun1 .............................................. [lun1 block/asm01_lvdaisy01 (rw)]
	  o- mapped_lun2 .............................................. [lun2 block/asm01_lvdaisy02 (rw)]
	  o- mapped_lun3 .............................................. [lun3 block/asm01_lvdaisy03 (rw)]
	  o- mapped_lun4 .............................................. [lun4 block/asm01_lvdaisy04 (rw)]
	  o- mapped_lun5 .............................................. [lun5 block/asm01_lvdaisy05 (rw)]
	  o- mapped_lun6 .............................................. [lun6 block/asm01_lvdaisy06 (rw)]
	  o- mapped_lun7 .............................................. [lun7 block/asm01_lvdaisy07 (rw)]
	  o- mapped_lun8 .............................................. [lun8 block/asm01_lvdaisy08 (rw)]
	  o- mapped_lun9 .............................................. [lun9 block/asm01_lvdaisy09 (rw)]
	  o- mapped_lun10 ............................................ [lun10 block/asm01_lvdaisy10 (rw)]
	  o- mapped_lun11 ............................................ [lun11 block/asm01_lvdaisy11 (rw)]

	alias: srvdaisy01.orcl  sid: 1 type: Normal session-state: LOGGED_IN
	alias: srvdaisy02.orcl  sid: 1 type: Normal session-state: LOGGED_IN
	# Connected !
	```

	TODO : Ajouter un screen de la commande `oracleasm listdisks`

3.	Installation du grid.

	`./install_grid.sh -db=daisy`

	Le grid est installé en standalone ou cluster en fonction de la configuration.
	Les scripts root sont exécutés sur l'ensemble des nœuds.

	Les 2 DGs DATA et FRA sont créées, pour un cluster il y a en plus le DG CRS

	__Note__ pour consommer le minimum de ressources un certain nombre de hacks
	sont fait, -no_hacks permet de ne pas les mettre en œuvre.

4.	Installation d'Oracle

	`./install_oracle.sh -db=daisy`

	Oracle est installé en standalone ou cluster. Les scripts root sont exécutés
	sur l'ensemble des nœuds.

5.	C'est terminé.

	[Création d'une base](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)
