### Scripts permettant d'agir sur les DGs.

* create_new_dg.sh : création d'un nouveau DG.

	Création d'un DG nommé ACFS avec 4 disques :

	```./create_new_dg.sh -name=ACFS -disks=4```

	[Procédure complète d'ajout de disques du SAN à la base.](https://github.com/PhilippeLeroux/plescripts/wiki/01-Ajout-de-disques-sur-des-DGs-Oracle)

* add_disk_to.sh : ajouter des disques à un DG existant.

	Ajout de 2 disques au DG ACFS :

	```./add_disk_to.sh -name=ACFS -disks=2```

* drop_oracleasm_disks.sh : supprime des disques d'oracleasm puis sur le SAN

	```./drop_oracleasm_disks.sh -db=albator -nr_disk=12 -count=4```

	Les disques de 12 à 15 seront supprimés sur l'ensemble des noeuds.

	Les LUNs correspondantes sur le SAN sont supprimées ainsi que les LVs.

	[Script créé suite à l'écriture de cette page de wiki](https://github.com/PhilippeLeroux/plescripts/wiki/02-Suppression-de-disques-sur-des-DGs-Oracle)
