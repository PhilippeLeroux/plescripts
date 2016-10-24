### Création de nouveaux serveurs :

**Note** : Tous les scripts sont exécutés depuis le poste client/serveur host.

Se postionner dans le répertoire `cd ~/plescripts/database_servers`

1.	Définir le serveur :

	* Création d'un serveur standalone : `./define_new_server.sh -db=daisy`
		
	  `daisy` est un identifiant qui devra être fournit à tous les autres scripts.

	   Le script affiche la configuration du réseau et des disques :

		```c
		# Node #1 standalone :
		#       Server name     srvdaisy01       : 192.170.100.18
		#       Interco iSCSI   srvdaisy01-iscsi : 66.60.60.18

		# DG DATA :
		#       S1DISKDAISY01  4Gb
		#       S1DISKDAISY02  4Gb
		#       S1DISKDAISY03  4Gb
		#       S1DISKDAISY04  4Gb
		#       S1DISKDAISY05  4Gb
		#       S1DISKDAISY06  4Gb
		#       S1DISKDAISY07  4Gb
		#       S1DISKDAISY08  4Gb
		#             8 disks 32Gb

		# DG FRA :
		#       S1DISKDAISY09  4Gb
		#       S1DISKDAISY10  4Gb
		#       S1DISKDAISY11  4Gb
		#       S1DISKDAISY12  4Gb
		#       S1DISKDAISY13  4Gb
		#       S1DISKDAISY14  4Gb
		#       S1DISKDAISY15  4Gb
		#       S1DISKDAISY16  4Gb
		#             8 disks 32Gb

		# Run : ./clone_master.sh -db=daisy
		```

	* Création d'un RAC 2 nœuds : `./define_new_server.sh -db=daisy -max_nodes=2`

	  `daisy` est un identifiant qui devra être fournit à tous les autres scripts.

	  Le script affiche la configuration du réseau et des disques :

		```c
		# Node #1 RAC :
		#       Server name     srvdaisy01       : 192.170.100.12
		#       VIP             srvdaisy01-vip   : 192.170.100.13
		#       Interco RAC     srvdaisy01-rac   : 66.60.20.12
		#       Interco iSCSI   srvdaisy01-iscsi : 66.60.60.12

		# Node #2 RAC :
		#       Server name     srvdaisy02       : 192.170.100.14
		#       VIP             srvdaisy02-vip   : 192.170.100.15
		#       Interco RAC     srvdaisy02-rac   : 66.60.20.14
		#       Interco iSCSI   srvdaisy02-iscsi : 66.60.60.14

		# scan : daisy-scan
		#        192.170.100.16
		#        192.170.100.17
		#        192.170.100.18

		# DG CRS :
		#       S1DISKDAISY01  6Gb
		#       S1DISKDAISY02  6Gb
		#       S1DISKDAISY03  6Gb
		#             3 disks 18Gb

		# DG DATA :
		#       S1DISKDAISY04  4Gb
		#       S1DISKDAISY05  4Gb
		#       S1DISKDAISY06  4Gb
		#       S1DISKDAISY07  4Gb
		#       S1DISKDAISY08  4Gb
		#       S1DISKDAISY09  4Gb
		#       S1DISKDAISY10  4Gb
		#       S1DISKDAISY11  4Gb
		#             8 disks 32Gb

		# DG FRA :
		#       S1DISKDAISY12  4Gb
		#       S1DISKDAISY13  4Gb
		#       S1DISKDAISY14  4Gb
		#       S1DISKDAISY15  4Gb
		#       S1DISKDAISY16  4Gb
		#       S1DISKDAISY17  4Gb
		#       S1DISKDAISY18  4Gb
		#       S1DISKDAISY19  4Gb
		#             8 disks 32Gb

		# Run : ./clone_master.sh -db=daisy -node=1
		```

	Ces informations sont enregistrées dans le champ description des VMs.

	Un nouveau répertoire nommé `daisy` est créée contenant les fichiers décrivant
	le paramétrage du ou des serveurs.

	Paramètres utiles :
	 * `-luns_hosted_by` permet de choisir si les disques sont gérés par le SAN ou VBox : `-luns_hosted_by=san|vbox`

	   Initialement j'avais prévu un disque dédié pour le SAN mais ce dernier est mort,
	   l'image disque du SAN est donc un disque vdi.

	 * `-size_dg_gb` permet de choisir la taille des DGs

2.	Clonage des VMs

	_Remarque :_  Le script `~/plescripts/yum/update_master.sh` met à jour les
	RPMs du master ce qui fait gagner du temps en particulier pour les RACs.

	* Cloner un serveur standalone : `./clone_master.sh -db=daisy`

	* Cloner le nœud d'un RAC      : `./clone_master.sh -db=daisy -node=1`

	Pour un RAC exécuter clone_master.sh autant de fois qu'il y a de noeuds en
	changeant le n° du nœud à chaque fois.

	Actions effectuées par le script :

	* Clone la VM master.
	* Renomme le serveur.
	* Configuration du réseau.
	* Création des disques.
	* Création des comptes oracle & grid.
	* Application des pré requis Oracle.
	* Établie les connections ssh sans mot de passe entre le poste client et
	le serveur avec les comptes root, grid et oracle.

	Le compte oracle est configuré pour se connecter grid sans mot de passe via
	l'alias sugrid.

	* Visualiser la configuration du DNS :

		```c
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
		```

	* Visualiser la configuration du SAN (Non valable si les LUNs sont sur VBox) :

		```c
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

		C'est `oracleasm` qui gère le 'mapping' des disques sur les serveurs de base de données.

5.	[Installation des logiciels Oracle](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/INSTALL_GRID_ORCL.md)
