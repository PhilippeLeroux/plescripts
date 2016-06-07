Objectif des scripts
====================
Le but des ces scripts et de créer une infrastructure complète avec un
minimum d'interventions 
	- La mémoire des machines virtuelles sera adaptée en fonction du type de base (SINGLE ou RAC)
	- Le DNS sera mis à jour.
	- Le SAN sera mis à jour.
	- Les horloges des serveurs synchronisées sur la même source.
	- Les disques seront montés via oracleasm. 

Création de nouveaux serveurs :
------------------------------
1)	new_infra.sh
	Permet de définir une nouvelle infrastructure.

2)	Lancer le(s) clonage(s) par le script virtualbox généré.

3)	Démarrer une des machines et une seule

4)	Lancer le script clone_master.sh

	Une fois qu'il est terminé recommencer à l'étape 3 avec une autre machine
	pour les RAC.

5)	install_grid.sh 
	Lance l'installation du grid sur le ou les nœuds concernées.


6)	install_oracle.sh 
	Lance l'installation de oracle sur le ou les nœuds concernés.

Ensuite créer les bases, un script est présent dans ~/plescripts/db





Recycler un serveur :
---------------------
Se connecter sur le serveur cible en root :
	cd ~/plescripts/infra
	./uninstall_all.sh -all
	./revert_to_master.sh -doit
Puis rebooter ou stopper le serveur.

Pour un RAC faire l'opération sur tous les serveurs.

Sont supprimés par le premier script :
	Les bases
	Oracle
	Le GI

Le second script supprime :
	Les comptes grid & oracle
	Renomme le serveur en orclmaster (cf variable master_name) et positionne
	l'IP qui va bien.

Depuis le poste client :
	cd ~/plescripts/infra
	./delete_infra.sh -db=<str> [-remove_cfg]
Le DNS et le SAN sont mis à jours.

License
-------

Copyright 2016 Philippe Leroux  - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)
