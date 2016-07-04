**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

# Objectifs :

Mettre en œuvre un réseau de VMs pour installer des bases Oracle de tout types en
essayant d'être le plus indépendant possible du logiciel de virtualisation utilisé.
La création des VMs ou des bases Oracle, en SINGLE ou RAC, ne demandent pas de
compétences particulières le tout étant automatisé, ainsi que la suppression.

La première version se basait sur KVM, Oracle Linux 6, OpenFiler et un serveur DNS.
Il était possible d'installer Oracle 11gR2 ou Oracle 12cR1 en SINGLE ou RAC.

Cette version se base maintenant uniquement sur Oracle Linux 7, OpenFiler est abandonné
pour targetcli qui a le gros avantage d'être scriptable, seul Oracle 12cR1 est
pris en charge et le RAC étendu n'est plus pris en compte.

L'hyperviseur n'est plus KVM mais VirtualBox qui a l'avantage d'être portable.
Une adaptation pour KVM sera sans doute effectuée.

--------------------------------------------------------------------------------

# Publics : DBA / Développeurs Oracle

--------------------------------------------------------------------------------

# Étapes pour la création d'une base :

La création d'une nouvelle base SINGLE ou RAC se fait en 5 étapes :
* Définition du nom de la base et du nombre de nœuds : le nom du ou des serveurs,
des disques sont définies à partir du nom de la base.

* Clonage du serveur de référence, actions effectuées :
	* Cloner la VM master.
	* Créer les disques sur le SAN : utilisation du protocole iscsi.
	* Enregistrer le serveur dans le DNS : utilisation de bind9.
	* Mapper les disques du SAN sur le ou les serveurs : utilisation d'oracleasm.

	Temps de clonage : ~8mn par serveurs.

* Installation du GI et création des DGs.

	Que la base soit SINGLE ou RAC il n'y a qu'un script à exécuter, les scripts
root de pré installations sont automatiquement exécutés sur le serveur ou l'ensemble
des nœuds d'un RAC.

	Temps d'installation RAC : ~35mn

* Installation d'Oracle

	Comme pour le GI un seul script prend en charge l'ensemble des opérations que
la base soit SINGLE ou bien RAC.

	Temps d'installation RAC : ~15mn

* Création d'une base de donner : un seul script également (Utilisation de dbca).

	Temps de création RAC cdb + 1 pdb : 1h20

--------------------------------------------------------------------------------
# Pré requis :
* Disposer d'une machine assez puissante pour un RAC il faut au minimum 8Gb de RAM.

* Télécharger les logiciels suivants :

	* [Download Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads)

	* [Download Oracle Linux 7](https://edelivery.oracle.com/osdc/faces/SearchSoftware)

	* [Download Oracle Database 12c & Grid Infrastructure 12c](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html)

--------------------------------------------------------------------------------

# Création des 2 premières VMs.
Instructions présentes ici : [README.md](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/README.md)

--------------------------------------------------------------------------------

# License

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
