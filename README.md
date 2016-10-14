### Objectifs :

Mettre en œuvre d'un réseau de VMs pour installer des bases Oracle de tout types
en essayant d'être le plus indépendant possible du logiciel de virtualisation utilisé.
La création des VMs ou des bases Oracle, en SINGLE ou RAC, ne demandent pas de
compétences particulières le tout étant automatisé.

La première version se basait sur KVM, Oracle Linux 6, OpenFiler et un serveur DNS.
Il était possible d'installer Oracle 11gR2 ou Oracle 12cR1 en SINGLE ou RAC.

Cette version se base maintenant uniquement sur Oracle Linux 7, OpenFiler est
abandonné pour targetcli qui a le gros avantage d'être scriptable, seul Oracle 12cR1
est pris en charge et le RAC étendu n'est plus pris en compte.

L'hyperviseur n'est plus KVM mais VirtualBox qui a l'avantage d'être portable.

--------------------------------------------------------------------------------

### Étapes pour la création d'une base :

La création d'une nouvelle base SINGLE ou RAC se fait en 5 étapes :

* Définir l'identifiant de la base et du nombre de nœuds : les noms des serveurs et
des disques sont déduits de l'identifiant.

* Clonage du serveur de référence : Temps ~5mn par serveur.

  Actions effectuées par le script de clonage :

	* Cloner la VM master.
	* Créer les disques :
	  * sur le SAN : utilisation du protocole iSCSI.
	  * ou sur VirtualBox
	  * [Benchs VBox VS iSCSI](https://github.com/PhilippeLeroux/plescripts/wiki/bench_vbox_iscsi) 
	* Enregistrer le serveur dans le DNS : utilisation de bind9.
	* Utilisation d'oracleasm pour la gestion des disques bdd.

* Installation du Grid Infrastructure et création des DGs : Temps ~35mn

	Que la base soit SINGLE ou RAC il n'y a qu'un script à exécuter, les scripts
root de pré installations sont automatiquement exécutés sur le serveur ou l'ensemble
des nœuds d'un RAC.

* Installation d'Oracle : Temps ~20mn

	Comme pour le Grid un seul script prend en charge l'ensemble des opérations que
la base soit SINGLE ou bien RAC.

* Création d'une base de données : Temps de création cdb + 1 pdb : ~25mn

--------------------------------------------------------------------------------
### Télécharger les logiciels suivants :

* [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads)

	Uniquement pour windows, sous linux yum install [...] ou apt-get install [...]

	Pour le moment le support de Windows est suspendu, il reprendra quand Ubuntu on Windows
	sera opérationnel et utilisable.

* [Oracle Linux 7, uniquement l'iso V100082-01.iso.](https://edelivery.oracle.com/osdc/faces/SearchSoftware)

* [Oracle Database 12c & Grid Infrastructure 12c](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html)

* Télécharger plescripts qui doit être extrait dans $HOME.
	* Avec git : `$ git clone https://github.com/PhilippeLeroux/plescripts.git`
	* Ou télécharger le zip en cliquant sur le boutton vert "Clone or download" en haut de la page.

--------------------------------------------------------------------------------

### Création des VMs orclmaster et K2.
2 VMs sont nécessaires pour commencer :
 - orclmaster qui est la VM clonée dès que l'on a besoin d'un nouveau serveur Oracle
 - K2 qui est le serveur d'infrastructure.

 [Création des VMs orclmaster et K2](https://github.com/PhilippeLeroux/plescripts/wiki/Cr%C3%A9ation-des-VMs-orclmaster-et-K2)

### Création des serveurs de base de données Oracle.
Les 2 VMs orclmaster et K2 doivent avoir été créées.

[Création des serveurs Oracle](https://github.com/PhilippeLeroux/plescripts/blob/master/database_servers/README.md)

La création des serveurs inclue l'installation du Grid Infrastructure et d'Oracle.
Une fois cette étape terminée les bases peuvent être [créées](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)

La création de dataguard est prise en compte mais uniquement pour des bases SINGLE, je n'ai pas assez de ressources pour avoir 2 RACs
ou 1 RAC et 1 SINGLE [procédure ici](https://github.com/PhilippeLeroux/plescripts/blob/master/db/stby/README.md)

##	Script database_servers/run_all.sh

**Note :** Exécuter ce script uniquement après avoir validé l'environnement en
créant au moins un serveur Oracle avec une base mono instance.

Ce script lance tous les scripts :
 - clone_master.sh
 - install_grid.sh
 - install_oracle.sh
 - create_db.sh
 - et éventuellement create_dataguard.sh

Exemples (ce postionner dans le répertoire ~/plescripts/database_servers) :
 - Création d'une base mono instance :

   `./run_all.sh -db=SIMPLE`

 - Création d'un RAC 2 nœuds :

   `./run_all.sh -db=RAC2N -max_nodes=2`

 - Création d'un dataguard :

   `./run_all.sh -db=saturne -standby=jupiter`

Les derniers paramètres seront passés à create_db.sh, pour créer un RAC 2 noeuds 'Policy Managed' par exemple :

`./run_all.sh -db=RAC2N -max_nodes=2 -policyManaged`

--------------------------------------------------------------------------------
[Mes notes](https://github.com/PhilippeLeroux/plescripts/wiki)
