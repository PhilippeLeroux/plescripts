### Objectifs :

Automatiser l'installation et la création de base de données Oracle, que ce soit
des bases mono instance, des bases en dataguard ou en RAC.
Le but est d'être le plus indépendant possible du logiciel de virtualisation.

Cette version se base maintenant uniquement sur Oracle Linux 7, OpenFiler est
abandonné pour targetcli qui a le gros avantage d'être scriptable, seul Oracle 12cR1
est pris en charge et le RAC étendu n'est plus pris en compte.
L'hyperviseur n'est plus KVM mais VirtualBox qui a l'avantage d'être portable.

--------------------------------------------------------------------------------

### Étapes pour la création d'une base :

Une fois les VMs master et K2 opérationnelles, la création d'une nouvelle base
SINGLE ou RAC se fait en 5 étapes :

1. Définir l'identifiant de la base et du nombre de nœuds : les noms des serveurs et
des disques sont déduits de l'identifiant.

2. Clonage du serveur de référence : ~5mn par serveur.

3. Installation du Grid Infrastructure et création des DGs

	* ~35mn pour un RAC 2 nœuds.
	* ~8mn pour une SINGLE.

4. Installation d'Oracle

	* ~20mn pour un RAC 2 nœuds.
	* ~5mn pour une SINGLE.


5. Création d'une base de données cdb + 1 pdb :

	* ~30mn pour un RAC 2 nœuds.
	* ~18mn pour une SINGLE.

--------------------------------------------------------------------------------
### Télécharger les logiciels suivants :

* [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads)

	Uniquement pour windows, sous linux yum install [...] ou apt-get install [...]

	Pour le moment le support de Windows est suspendu, il reprendra quand Ubuntu on Windows
	sera opérationnel et utilisable.

* Oracle Linux 7, uniquement l'ISO [V100082-01.iso](https://edelivery.oracle.com/osdc/faces/SearchSoftware) est nécessaire. Rechercher Linux 7, puis décocher les autres ISO.

* 4 archives [Oracle Database 12c & Grid Infrastructure 12c](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html)

* Télécharger plescripts qui doit être extrait dans $HOME.
	* Avec git : `$ git clone https://github.com/PhilippeLeroux/plescripts.git`
	* Ou télécharger le zip en cliquant sur le boutton vert "Clone or download" en haut de la page.

--------------------------------------------------------------------------------

### Création des VMs orclmaster et K2.
2 VMs sont nécessaires pour commencer :
 - orclmaster qui est la VM clonée dès que l'on a besoin d'un nouveau serveur Oracle
 - K2 qui est le serveur d'infrastructure (DNS, SAN, NTP server, ...)

 [Instructions](https://github.com/PhilippeLeroux/plescripts/wiki/Cr%C3%A9ation-des-VMs-orclmaster-et-K2)

--------------------------------------------------------------------------------

### Création des serveurs de base de données Oracle.

[Instructions](https://github.com/PhilippeLeroux/plescripts/blob/master/database_servers/README.md)

La création des serveurs inclue l'installation du Grid Infrastructure et d'Oracle.
Une fois cette étape terminée les bases peuvent être [créées](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)

La mise en dataguard de 2 serveurs standalone est prise en compte, instructions [ici](https://github.com/PhilippeLeroux/plescripts/blob/master/db/stby/README.md)

--------------------------------------------------------------------------------

##	Scripts complémentaires.

 * vbox_run_all.sh : utilise des disques VBox pour les LUNs de base de données.
 * iscsi_run_all.sh : utilise des disques exportés via iSCSI depuis K2 pour les LUNs de base de données.

**Note :** Initialement ces scripts ont été conçues pour automatiser les jeux de tests.

Exécuter ces scripts uniquement après avoir validé l'environnement en créant au moins
un serveur Oracle avec une base mono instance.

Ce script lance tous les scripts :
 - define_new_server.sh
 - clone_master.sh
 - install_grid.sh
 - install_oracle.sh
 - create_db.sh
 - et éventuellement create_dataguard.sh

Exemples, ce postionner dans le répertoire `~/plescripts/database_servers` :
 - Création d'une base mono instance : `./vbox_run_all.sh -db=SINGLE`

 - Création d'un RAC 2 nœuds : `./vbox_run_all.sh -db=RAC2N -max_nodes=2`

 - Création d'un dataguard : `./vbox_run_all.sh -db=saturne -standby=jupiter`

Les derniers paramètres seront passés à create_db.sh, pour créer un RAC 2 nœuds 'Policy Managed' par exemple : `./vbox_run_all.sh -db=RAC2N -max_nodes=2 -policyManaged`

Si l'un des paramètres est invalide, le script create_db.sh plantera.

--------------------------------------------------------------------------------
[Mes notes](https://github.com/PhilippeLeroux/plescripts/wiki)
