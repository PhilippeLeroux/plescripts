**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

Objectif des scripts
====================

Le but des ces scripts et de créer une infrastructure complète avec un
minimum d'interventions

	- La mémoire des machines virtuelles est adaptée en fonction du type de base
	SINGLE ou RAC
	- Le DNS est mis à jour.
	- Le SAN est mis à jour.
	- Les horloges des serveurs synchronisées sur la même source.
	- Les disques sont attachés via oracleasm.

Si votre poste client est Windows connectez vous sur K2 en root avec putty.
Toutes les opérations se font depuis le répertoire plescripts/database_server.

Création de nouveaux serveurs :
------------------------------

1.	Définir le serveur :

	Création d'un serveur standalone : `./define_new_server.sh -db=babar`

	Création d'un RAC 2 noeuds : `./define_new_server.sh -db=babar -max_nodes=2`

	Un nouveau répertoire nommé babar est crée contenant les fichiers décrivant
	le paramétrage du ou des serveurs.

	Par défaut les DGs DATA et FRA ont une taille de 24Gb chacun, la taille
	peut être changée à l'aide du paramètre -size_dg_gb

	Dans le cas d'un serveur standalone sont crées :

		1 serveur nommé  :	srvbabar01
		8 disques nommés :	S1DISKBABAR01,S1DISKBABAR02,..., S1DISKBABAR08

	Dans la cas d'un RAC 2 noeuds on a un serveur de plus srvbabar02 et 3
	disques supplémentaires pour le CRS

2.	Clonage.

	Exécuter le script présent dans le répertoire "shared/BABAR/clone/"

	Pour une base SINGLE le master est cloné puis démarré.

	Pour une base RAC tous les nœuds sont clonés depuis master mais seul le
	premier nœud est démarré.

	*Il ne faut pas démarrer 2 VMs venant d'être crées, elles ont le même nom et
	la même adresse IP.*

3.	Configuration des VMs

	Configurer un serveur standalone : `./clone_master.sh -db=babar`

	Configurer le nœud d'un RAC      : `./clone_master.sh -db=babar -node=1`

	(Le RAC one node n'est pas encore 100% opérationnel.)

	Pour un RAC démarrer la VM suivante et relancer clone_master.sh en
	changeant le n° du nœud.

	Actions effectuées par le script :

		* Renomme le serveur
		* Configuration du réseau.
		* Création des disques.
		* Création des comptes oracle & grid.
		* Application des pré requis Oracle.
		* Établie les connections ssh sans mot de passe entre le poste client et
		le serveur avec les comptes root, grid et oracle.

	Le compte oracle est configuré pour se connecter grid sans mot de passe via
	l'alias sugrid.

4.	Installation du grid.

	`./install_grid.sh -db=babar`

	Installe le grid en standalone ou cluster. Les scripts root sont exécutés
	sur l'ensemble des nœuds.

	Les 2 DGs DATA et FRA sont crées, pour un cluster il y a en plus le DG CRS

5.	Installation d'Oracle

	`./install_oracle.sh -db=babar`

	Installe oracle en standalone ou cluster. Les scripts root sont exécutés
	sur l'ensemble des nœuds.

6.	C'est terminé.

	Pour créer une base voir [README.md](https://github.com/PhilippeLeroux/plescripts/db/README.md)

Recycler un serveur :
---------------------

Se connecter sur le serveur cible en root :

	- cd ~/plescripts/database_server
	- ./uninstall_all.sh -type=FS|ASM
	- ./revert_to_master.sh -doit
	- Puis rebooter ou stopper le serveur.
	- Pour un RAC exécuter ./revert_to_master.sh -doit sur tous les nœuds.

Depuis le poste client :

	- cd ~/plescripts/database_server
	- ./remove_server.sh -db=<str> [-remove_cfg]
	- Le DNS et le SAN sont mis à jours.

--------------------------------------------------------------------------------

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
