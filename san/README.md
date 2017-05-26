__Gestion disque SAN :__

* [Augmenter la taille disque du SAN](https://github.com/PhilippeLeroux/plescripts/wiki/san_extend_vg)

* [Création/suppression du VG asm01](https://github.com/PhilippeLeroux/plescripts/wiki/Cr%C3%A9ation-du-VG-asm01-sur-le-serveur-d'infra)

* [Suppression / Migration de disques](https://github.com/PhilippeLeroux/plescripts/wiki/VG-:-migration-disques)

* [Erreur target au démarrage de K2](https://github.com/PhilippeLeroux/plescripts/wiki/Problèmes-démarrage-target)

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
