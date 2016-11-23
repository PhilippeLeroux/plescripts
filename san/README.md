__Erreurs disques récurrentes :__ [corrections](https://github.com/PhilippeLeroux/plescripts/wiki/SAN-disks-errors)

__Bookmarks__

Un bookmark est créé par serveur permettant de visualiser les LUNs qui  lui sont
associées.

Par exemple pour un RAC 2 nœuds composés des serveurs srvphilae01 et srvphilae02
les bookmarks srvphilae01 et srvphilae02 permettent de visualiser leurs LUNs :
```
[root@K2 san]# targetcli ls @srvphilae01
o- iqn.1970-05.com.srvphilae:01 ..................................................... [Mapped LUNs: 11]
  o- mapped_lun1 ................................................... [lun1 block/asm01_lvphilae01 (rw)]
  o- mapped_lun2 ................................................... [lun2 block/asm01_lvphilae02 (rw)]
  o- mapped_lun3 ................................................... [lun3 block/asm01_lvphilae03 (rw)]
  o- mapped_lun4 ................................................... [lun4 block/asm01_lvphilae04 (rw)]
  o- mapped_lun5 ................................................... [lun5 block/asm01_lvphilae05 (rw)]
  o- mapped_lun6 ................................................... [lun6 block/asm01_lvphilae06 (rw)]
  o- mapped_lun7 ................................................... [lun7 block/asm01_lvphilae07 (rw)]
  o- mapped_lun8 ................................................... [lun8 block/asm01_lvphilae08 (rw)]
  o- mapped_lun9 ................................................... [lun9 block/asm01_lvphilae09 (rw)]
  o- mapped_lun10 ................................................. [lun10 block/asm01_lvphilae10 (rw)]
  o- mapped_lun11 ................................................. [lun11 block/asm01_lvphilae11 (rw)]
[root@K2 san]# targetcli ls @srvphilae02
o- iqn.1970-05.com.srvphilae:02 ..................................................... [Mapped LUNs: 11]
  o- mapped_lun1 ................................................... [lun1 block/asm01_lvphilae01 (rw)]
  o- mapped_lun2 ................................................... [lun2 block/asm01_lvphilae02 (rw)]
  o- mapped_lun3 ................................................... [lun3 block/asm01_lvphilae03 (rw)]
  o- mapped_lun4 ................................................... [lun4 block/asm01_lvphilae04 (rw)]
  o- mapped_lun5 ................................................... [lun5 block/asm01_lvphilae05 (rw)]
  o- mapped_lun6 ................................................... [lun6 block/asm01_lvphilae06 (rw)]
  o- mapped_lun7 ................................................... [lun7 block/asm01_lvphilae07 (rw)]
  o- mapped_lun8 ................................................... [lun8 block/asm01_lvphilae08 (rw)]
  o- mapped_lun9 ................................................... [lun9 block/asm01_lvphilae09 (rw)]
  o- mapped_lun10 ................................................. [lun10 block/asm01_lvphilae10 (rw)]
  o- mapped_lun11 ................................................. [lun11 block/asm01_lvphilae11 (rw)]
```

--------------------------------------------------------------------------------

Ces scripts prennent en charge la création des LVs et de l'export sur le réseau.

Cette page décrit brièvement les scripts, pour avoir des informations _plus fonctionnelles_
sur la façon de se servir des scripts :
* [Ajout de disques](https://github.com/PhilippeLeroux/plescripts/wiki/01-Ajout-de-disques-sur-des-DGs-Oracle)
* [Suppression de disques](https://github.com/PhilippeLeroux/plescripts/wiki/02-Suppression-de-disques-sur-des-DGs-Oracle)

--------------------------------------------------------------------------------

__Bibliothèques :__

* `targetclilib.sh` : contient toutes les fonctions permettant de manipuler targetcli
* `lvlib.sh` : fonction courante de manipulation des LVs.

--------------------------------------------------------------------------------

__Création de nouveaux disques :__

create_lun_for_db.sh est utilisé par clone_master.sh, ce script va enchainer les
scripts de plus bas niveaux pour créer les disques et les exporter sur le réseau.

Ne peut être utilisé hors du script clone_master.sh.

--------------------------------------------------------------------------------

__Description des scripts__

Les scripts ci dessous sont les scripts de bases, voir plutôt la documentation
'fonctionnelle' et n'utiliser ces scripts que lors de problèmes.

Avant d'utiliser un script utiliser le paramètre -h, la majorité des scripts doit
être documentée.

* create_initiator.sh : Création de l'initiator dans targetcli.

* Ajout de disques et/ou exports
	* add_and_export_lv.sh : Création des LVs dans un VG puis export dans targetcli

	* export_lv.sh : Export de LVs existants dans targetcli.

	Les LUNs seront visibles pour les serveurs clients.

Puis aller sur le client pour mapper les LUNs (cf répertoire disk)

* delete_db_lun.sh

	Permet de détruire 1 ou plusieurs LUNs correspondant à un identifiant de base (ex -prefix=daisy)

* create_lv.sh
	
	Création de 1 ou plusieurs LVs dans un VG.

	Ce script s'assure que les normes sont respectées.

* remove_lv.sh
	
	Suppression de 1 ou plusieurs LVs dans un VG.
	
	L'entête des LVs est effacé.

	Ne fonctionne que pour les LVs crées par create_lv.sh

* reset_all_for_db.sh
	
	Supprime-le ou les initiators pour une base, le backstore et tous les LVs de
	la base seront remis à zéro.
	
* delete_intiator.sh

	Supprime un initiator le backstore reste intacte.	

* delete_backstore.sh

	Supprime un backstore, échouera si un initiator utilise un des disques
	du backstore.
		
	Les LVs restent intactes.
