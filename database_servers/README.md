**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

Objectif des scripts
====================

Le but de ces scripts et de créer une infrastructure complète avec un minimum
d'interventions

Toutes les actions nécessaires sur K2 sont scriptées et transparente :
- Le DNS est mis à jour.
- Le SAN est mis à jour.
- Les horloges des serveurs synchronisées sur la même source.
- Les disques sont attachés via oracleasm.

La VM master sera cloné afin d'éviter d'installer l'OS à chaque fois.

**Note** : Tous les scripts sont exécutés depuis le poste client.

Création de nouveaux serveurs :
------------------------------

1.	Définir le serveur :

	Création d'un serveur standalone : `./define_new_server.sh -db=daisy`

	Création d'un RAC 2 nœuds : `./define_new_server.sh -db=daisy -max_nodes=2`

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

	Visuliser la configuration du DNS et du SAN.
	```
	ssh root@K2
	cd plescripts/dns
	./show_dns.sh
	```

	![Broken DNS](https://github.com/PhilippeLeroux/plescripts/blob/master/database_servers/screen/show_dns_daisy.png "DNS")

	```
	cd ../san
	./show_db_info.sh -db=daisy
	```

	![Broken SAN](https://github.com/PhilippeLeroux/plescripts/blob/master/database_servers/screen/show_san_daisy.png "SAN")

	Note : sur ce screen il y a 4 LUNs en plus par rapport à ce que vous obtiendrez.

3.	Installation du grid.

	`./install_grid.sh -db=daisy`

	Installe le grid en standalone ou cluster. Les scripts root sont exécutés
	sur l'ensemble des nœuds.

	Les 2 DGs DATA et FRA sont créées, pour un cluster il y a en plus le DG CRS

	__Note pour le RAC__ pour consommer le moins de ressources possible :
	 - tfa est désintallé.
	 - des services sont désactivés.
	 - La memory_target d'ASM est diminuée.
	 - la 'mgmt database' n'est pas installée.

	Si vous disposez de bons CPUs et au moins 4Gb de RAM par VM alors utiliser
	l'option -install_mgmtdb qui n'effectuera pas ces actions.

4.	Installation d'Oracle

	`./install_oracle.sh -db=daisy`

	Installe oracle en standalone ou cluster. Les scripts root sont exécutés
	sur l'ensemble des nœuds.

5.	C'est terminé.

	[Création d'une base](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)


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
