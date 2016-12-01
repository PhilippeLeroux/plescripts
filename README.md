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

1. Définir l'identifiant de la base et le nombre de nœuds.

2. Clonage du serveur de référence : ~5mn par serveur.

3. Installation du Grid Infrastructure et création des DGs

	* ~35mn pour un RAC 2 nœuds.
	* ~8mn pour une SINGLE.

4. Installation d'Oracle

	* ~20mn pour un RAC 2 nœuds.
	* ~5mn pour une SINGLE.


5. Création d'une base de données CDB + 1 PDB :

	* ~30mn pour un RAC 2 nœuds.
	* ~18mn pour une SINGLE.

--------------------------------------------------------------------------------
### Télécharger les logiciels suivants :

* VirtualBox
  * Linux : zypper install [...] ou yum install [...] ou apt-get install [...] en fonction de la distribution.
	(Testé uniquement avec tumbleweed)

  * _Windows télécharger [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads) (Windows n'est plus pris en compte pour le moment.)_

* Oracle Linux 7 : uniquement l'ISO [V100082-01.iso](https://edelivery.oracle.com/osdc/faces/SearchSoftware) est nécessaire. Rechercher Linux 7, puis décocher les autres ISO.

* [Oracle Database 12c & Grid Infrastructure 12c](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html)

* plescripts qui doit être extrait dans $HOME.
	* Avec git : `$ git clone https://github.com/PhilippeLeroux/plescripts.git`
	* Ou télécharger le zip en cliquant sur le boutton vert "Clone or download" en haut de la page.

--------------------------------------------------------------------------------

### Création des VMs orclmaster et K2.
2 VMs sont nécessaires pour commencer : [instructions](https://github.com/PhilippeLeroux/plescripts/wiki/Création-des-VMs-orclmaster-et-K2)
 - orclmaster qui est la VM clonée dès que l'on a besoin d'un nouveau serveur Oracle
 - K2 qui est le serveur d'infrastructure (DNS, SAN, Gateway, NTP server, ...)

--------------------------------------------------------------------------------

### Création des serveurs de base de données Oracle.

* Création serveurs : [instructions](https://github.com/PhilippeLeroux/plescripts/wiki/Create-servers)

* Installation du Grid Infra & d'Oracle : [instructions](https://github.com/PhilippeLeroux/plescripts/wiki/Installation-:-Grid-infra-&-Oracle)

* Création d'une base : [instructions](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)

* Mise en dataguard de 2 serveurs standalones : [instructions](https://github.com/PhilippeLeroux/plescripts/blob/master/db/stby/README.md)

--------------------------------------------------------------------------------

##	Script `run_all.sh`

Le script `run_all.sh` permet de lancer tous les scripts simultanément, initialement
il sert comme jeu de test mais est finalement bien pratique.

Exécuter ces scripts uniquement après avoir validé l'environnement en créant au moins
un serveur Oracle avec une base mono instance.

Ce script lance les scripts :
 - define_new_server.sh
 - clone_master.sh
 - install_grid.sh
 - install_oracle.sh
 - create_db.sh
 - et éventuellement create_dataguard.sh

Paramètres utiles :
 - -vbox permet de faire gérer les LUNs par VBox.
 - -db_size_gb=# indique la taille de la base souhaitée.
 - -standby=db identifiant de la standby.
 - -h  permet d'avoir la liste exhaustive des paramètres.

Exemples, se positionner dans le répertoire `~/plescripts/database_servers` :
 - Création d'une base mono instance : `./run_all.sh -vbox -db=SINGLE`

 - Création d'un RAC 2 nœuds : `./run_all.sh -db=RAC2N -max_nodes=2`

 - Création d'un dataguard : `./run_all.sh -db=saturne -standby=jupiter`

Dès qu'un paramètre est inconnu pour `run_all.sh` ce paramètre et tous les suivants
sont transmis au script `create_db.sh`

Par exemple : `./run_all.sh -db=RAC2N -max_nodes=2 -policyManaged`

Le paramètre `-policyManaged` est passé au script `create_db.sh`

Si l'un des paramètres est invalide, le script create_db.sh plantera.

##	Temps de références
### Création d'un dataguard (Base single)

script				|	id					|	temps
--------------------|:---------------------:|-------------:
clone_master.sh		|	venus				|	   3mn17s
install_grid.sh		|	venus				|	   7mn10s
install_oracle.sh	|	venus				|	   3mn46s
create_db.sh		|	venus				|	 19mn58s
clone_master.sh		|	saturne				|	   3mn40s
install_grid.sh		|	saturne				|	   7mn34s
install_oracle.sh	|	saturne				|	   4mn14s
create_dataguard.sh	|	VENUS with SATURNE	|	  11mn12s
run_all.sh			|	venus				|	1h01mn04s

###	Création d'un RAC

script				|	id					|	temps
--------------------|:---------------------:|-------------:
clone_master.sh		|	daisy				|	4mn15s
clone_master.sh		|	daisy				|	3mn37s
install_grid.sh		|	daisy				|	31mn46s
install_oracle.sh	|	daisy				|	13mn13s
create_db.sh		|	daisy				|	54mn29s
run_all.sh			|	daisy				|	1h47mn26s

--------------------------------------------------------------------------------

![Screenshot](https://github.com/PhilippeLeroux/plescripts/wiki/virtualbox_manager.png)

--------------------------------------------------------------------------------
[Mes notes](https://github.com/PhilippeLeroux/plescripts/wiki)
