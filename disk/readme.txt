**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

Description
===========
Répertoire plescript/disk : permet de gérer les disques du serveur.

1. Ajouter des disques dans oracleasm.

	Lorsque des disques sont ajoutés sur le SAN exécuter avec le compte root les 2 commandes :
	`./create_partitions_on_new_disks.sh` : Crée des partitions sur les nouveaux disques.
	`./create_oracle_disk_on_new_part.sh` : Crée des disques Oracle sur les nouvelles partitions.

	Pour ajouter les disques dans ASM se connecter grid et aller dans le répertoire plescripts/dg.


2.	Scripts pouvant être utiles.

*	Vérifier l'état des disques utilisés par oracleasm `check_oracle_disks.sh`

*	Visualiser les disques iscsi : `show_iscsi_session.sh`

*	Supprimmer de oracleasm tous les disques : `release_oracle_disks.sh`

	*Les disques ne sont pas effacés, ils restent donc utilisables*


3.	Scripts utilisés lors de la création d'un serveur ou lors du recyclage d'un
	serveur.

*	Effacer les en-têtes des disques utilisés par oracleasm : `clear_oracle_disk_headers.sh`
	
	*Une fois ce script exécuté oracleasm n'a plus aucun disque.*

*	Déconnecter toutes les LUNs : `logout_sessions.sh`

*	Permet de se connecter sur la target : `discovery_target.sh`

*	Lie tous les disques iscsi et donne leur type : `check_disks_type.sh`

*	Efface les en-têtes des disques iscsi : `clear_all_iscsi_header.sh`

*	create_oracle_fs_on_new_disks.sh	
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

License
-------

Copyright (©) 2016 Philippe Leroux - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
