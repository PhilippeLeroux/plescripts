Cette page décrit brièvement les scripts, pour avoir des informations _plus fonctionnelles_
sur la façon de se servir des scripts :
* [Ajout de disques](https://github.com/PhilippeLeroux/plescripts/wiki/01-Ajout-de-disques-sur-des-DGs-Oracle)
* [Suppression de disques](https://github.com/PhilippeLeroux/plescripts/wiki/02-Suppression-de-disques-sur-des-DGs-Oracle)

--------------------------------------------------------------------------------

### Description

Permet de gérer les disques d'un serveur de base de données.

1. Ajouter des disques dans oracleasm.

	Lorsque des disques sont ajoutés sur le SAN exécuter avec le compte root les 2 commandes :
	`./create_partitions_on_new_disks.sh` : crée des partitions sur les nouveaux disques.
	`./create_oracle_disk_on_new_part.sh` : crée des disques Oracle sur les nouvelles partitions.

	Pour ajouter les disques dans ASM se connecter grid et aller dans le répertoire plescripts/dg.

2.	Scripts pouvant être utiles.

	* Vérifier l'état des disques utilisés par oracleasm `check_oracle_disks.sh`

	* Visualiser les disques iscsi : `show_iscsi_session.sh`

	* Supprimer d'oracleasm tous les disques : `release_oracle_disks.sh`

		*Les disques ne sont pas effacés, ils restent donc utilisables*


3.	Scripts utilisés lors de la création d'un serveur ou lors du recyclage d'un
	serveur.

	* Effacer les en-têtes des disques utilisés par oracleasm : `clear_oracle_disk_headers.sh`

		*Une fois ce script exécuté oracleasm n'a plus aucun disque.*

	* Déconnecter toutes les LUNs : `logout_sessions.sh`

	* Permet de se connecter sur la target : `discovery_target.sh`

	* Lie tous les disques iscsi et donne leur type : `check_disks_type.sh`

	* Efface les en-têtes des disques iscsi : `clear_all_iscsi_header.sh`

	* create_oracle_fs_on_new_disks.sh
		* Recherche un disque iscsi non utilisé.
		* Crée le point de montage /u01/app/oracle/oradata
		* Crée un VG vg_oradata
		* Crée un LV lv_oradata
		* Crée un FS sur le LV
		* Monte /u01/app/oracle/oradata sur lv_oradata

*	oracleasm_discovery_first_node.sh

	Ce script est utilisé par `clone_master.sh`, il effectue toutes les actions
	nécessaires pour créer les disques sur le premier nœud d'un RAC ou un serveur
	standalone.

*	oracleasm_discovery_other_nodes.sh

	Est utilisé par `clone_master.sh` pour ajouter les disques sur les autres nœuds
	d'un RAC.
