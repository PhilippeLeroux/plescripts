**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------
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

__Utilisation des scripts génériques :__

* create_initiator.sh : Création de l'initiator dans targetcli.

* Ajout de disques et/ou exports
	* add_and_export_lv.sh : Création des LVs dans un VG puis export dans targetcli

	* export_lv.sh : Export de LVs existants dans targetcli.

	Les LUNs seront visibles pour les serveurs clients.

Puis aller sur le client pour mapper les LUNs (cf répertoire disk)

--------------------------------------------------------------------------------

__Scripts divers :__

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
