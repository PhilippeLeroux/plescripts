Objectif des scripts
====================
Le but des ces scripts et de créer une infrastructure complète avec un
minimum d'interventions

	- La mémoire des machines virtuelles sera adaptée en fonction du type de base
	  SINGLE ou RAC
	- Le DNS sera mis à jour.
	- Le SAN sera mis à jour.
	- Les horloges des serveurs synchronisées sur la même source.
	- Les disques seront montés via oracleasm.

Note :

	- Le support des bases sur FS a été inclue alarache, l'objectif initial étant
	de gérer le stockage des bases uniquement depuis ASM.

Création de nouveaux serveurs :
------------------------------
1)	new_infra.sh
	Permet de définir une nouvelle infrastructure.

	./new_infra.sh -db=babar

	Définie une infrastructure babar pour une base SINGLE.
	Un répertoire babar est crée contenant la description de la base.

	Pour créer une RAC 2 noeuds : ./new_infra.sh -db=babar -max_nodes=2

2)	Lancer le(s) clonage(s) par le script virtualbox généré.
	En fonction du guess des fichiers .sh ou .bat sont crées. Ils ont pour but
	de créer des VMs conformes.

	Actuellement seule les scripts pour VBOX sont générés que ce soit pour un
	guess sous Windows ou Linux.

	Les scripts sont disponibles sour "shared/BABAR"

	A l'avenir les scripts pour KVM seront également générés.

3)	Lancer le clonage.

	Exécuter le script présent dans le répertoire "shared/BABAR/clone/"

	Pour une base SINGLE le master est cloné puis démarré.

	Pour une base RAC tous les nœuds sont clonés depuis master mais seul le
	premier nœud est démarré.

4)	Lancer le script clone_master.sh

	Pour une base SINGLE : ./clone_master.sh -db=babar

	Pour une base RAC : ./clone_master.sh -db=babar -node=1

	Pour un RAC démarrer la VM suivante et relancer clone_master.sh en changeant
	le n° du noeud.

5)	install_grid.sh

	./install_grid.sh -db=babar

	Installera le grid en standalone ou cluster.

	Tous les scripts pré install seront exécutés.

6)	install_oracle.sh

	./install_oracle.sh -db=babar

	Installera oracle en standalone ou cluster.

	Tous les scripts pré installe seront exécutés.

7)	Création de la base.

	Se connecter sur le premier nœud et voir le README.md dans ~/plescripts/db

Recycler un serveur :
---------------------
Se connecter sur le serveur cible en root :

	- cd ~/plescripts/infra
	- ./uninstall_all.sh -type=FS|ASM
	- ./revert_to_master.sh -doit
	- Puis rebooter ou stopper le serveur.
	- Pour un RAC exécuter ./revert_to_master.sh -doit sur tous les nœuds.

Depuis le poste client :
	
	- cd ~/plescripts/infra
	- ./delete_infra.sh -db=<str> [-remove_cfg]
	- Le DNS et le SAN sont mis à jours.

License
-------

Copyright 2016 Philippe Leroux  - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)

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
