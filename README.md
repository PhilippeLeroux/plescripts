**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

                    __        __         _
                    \ \      / /__  _ __| | __
                     \ \ /\ / / _ \| '__| |/ /
                      \ V  V / (_) | |  |   <
                       \_/\_/ \___/|_|  |_|\_\
                             ___
                            |_ _|_ __
                             | || '_ \
                             | || | | |
                            |___|_| |_|
                 ____
                |  _ \ _ __ ___   __ _ _ __ ___  ___ ___
                | |_) | '__/ _ \ / _` | '__/ _ \/ __/ __|
                |  __/| | | (_) | (_| | | |  __/\__ \__ \
                |_|   |_|  \___/ \__, |_|  \___||___/___/
                                 |___/

--------------------------------------------------------------------------------

# Objectifs :

Mettre en œuvre un réseau de VMs pour installer des bases Oracle de tout types en
essayant d'être le plus indépendant possible du logiciel de virtualisation utilisé.
La création des VMs ou des bases Oracle, en SINGLE ou RAC, ne demandent pas de
compétences particulières le tout étant automatisé, ainsi que la suppression.

La première version se basait sur KVM, Oracle Linux 6, OpenFiler et un serveur DNS.
Il était possible d'installer Oracle 11gR2 ou Oracle 12cR1 en SINGLE ou RAC.

Cette version ce base maintenant uniquement sur Oracle Linux 7, OpenFiler est abandonné
pour targetcli qui à le gros avantage d'être scriptable et seul Oracle 12cR1 est
pris en charge.

L'hyperviseur n'est plus KVM mais VirtualBox qui a l'avantage d'être portable,
mais il fort probable que je finisse par utiliser KVM dans un futur proche en
essayant de toujours fonctionner avec VirtualBox pour linux.

--------------------------------------------------------------------------------

# Description rapide de la création d'une base :

La création d'une nouvelle base SINGLE ou RAC se fait en 5 étapes :
* Définition du nom de la base et du nombre de nœuds : le nom du ou des serveurs,
des disques sont définies à partir du nom de la base.

* Clonage du serveur de référence, actions effectuées :
	* Cloner la VM master (sous Windows l'action est manuelle).
	* Créer les disques sur le SAN : utilisation du protocole iscsi.
	* Enregistrer le serveur dans le DNS : utilisation de bind9.
	* Mapper les disques du SAN sur le ou les serveurs : utilisation d'oracleasm.

* Installation du GI (Les bases SINGLE sur FS sont possibles mais pas documentées).

	Que la base soit SINGLE ou RAC il n'y a qu'un script à exécuter, les scripts
root pré installation sont automatiquement exécuter sur le serveur ou l'ensemble
des nœuds d'un RAC.

* Installation d'Oracle

	Comme pour le GI un seul script prend en charge l'ensemble des opérations que
la base soit SINGLE ou bien RAC.

* Création d'une base de donner : un seul script également (Utilisation de dbca).

--------------------------------------------------------------------------------

L'étape n° 1 (la plus délicate) consiste à créer 2 VMs :
* La première, K2, qui servira de serveur d'infrastructure, dont **les** rôles sont :

	* SAN : gestion des disques via targetcli.
	* DNS : gestion des noms des serveurs et des adresses de SCAN pour le RAC.
	* Passerelle : les serveurs de base de données ne peuvent pas accéder directement
à internet, utile pour les yum update par exemple, ils passent donc par le serveur
d'infrastructure.
	* Serveur de temps : l'ensemble des VMs du réseau sont synchronisées sur ce serveur.

* La seconde, orclmaster, qui servira de master, elle aura une configuration minimale.

--------------------------------------------------------------------------------
# Pré requis :
* Disposer d'une machine assez puissant, pour une RAC il faut au minimum 8Gb de RAM.

* Télécharger les logiciels suivants :

	* [Download Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads)

	* [Download Oracle Linux 7](https://edelivery.oracle.com/osdc/faces/SearchSoftware)

	* [Download Oracle Database 12c & Grid Infrastructure 12c](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html)

--------------------------------------------------------------------------------

# Documentation.
L'infrastructure ne devrait plus changer en profondeur, **la documentation est donc
en cour**

--------------------------------------------------------------------------------

License
=======

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
