Description
===========

1)	discovery_target.sh
	Permet de connecter sur la target.
	Utiliser uniquement lors de la création du serveur, il n'y a que très peu
	de raison d'utiliser ce script.

2)	create_partitions_on_new_disks.sh
	scan si la target présente de nouveaux paths si c'est le cas
	crée une partition


3)	create_oracle_disk_on_new_part.sh
	Création d'un disque Oracle (oracleasm) sur les partitions disponibles.

Lorsque des disques sont ajoutés sur le SAN lancer en root les 2 commandes 
	./create_partitions_on_new_disks.sh
	./create_oracle_disk_on_new_part.sh

Pour ajouter les disques dans ASM se connecter grid ou oracle et aller dans dg.

License
-------

Copyright 2016 Philippe Leroux  - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)
