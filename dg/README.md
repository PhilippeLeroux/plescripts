# Scripts permettant d'agir sur les DGs.

* create_new_dg.sh : création d'un nouveau DG.

	Création d'un DG nommé ACFS avec 4 disques :
	
	./create_new_dg.sh -name=ACFS -disks=4

	S'il n'y a pas assez de disques le script échoue.

* add_disk_to.sh : ajouter des disques à un DG existant.

	Ajout de 2 disques au DG ACFS :

	./add_disk_to.sh -name=ACFS -disks=2

	S'il n'y a pas assez de disques le script échoue.
