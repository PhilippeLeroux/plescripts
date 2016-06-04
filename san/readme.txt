targetclilib.sh
	contient toutes les fonctions permettant de manipuler targetcli

lvlib.sh
	fonction courante de manipulation des LVs.

Le but de ces scripts est de normaliser les différents noms utilisés.
Normalement il n'y a pas besoin d'appeler les commandes de l'os sauf pour
la création du VG.

Note : le VG recevant la LUN doit exister.

Création de nouveaux disques pour un client (initiator)
=======================================================
Scripts d'automatisations Oracle :
----------------------------------
	Le scripts clone_master.sh appel uniquement le script
	create_lun_for_db.sh qui s'occupe de toutes les étapes.

Utilisation des scripts génériques :
------------------------------------
	1) create_initiator.sh
		Création de l'initiator dans targetcli.

	2)
		2.1) add_and_export_lv.sh
			 Création des LV dans un VG puis export dans targetcli

		2.2) export_lv.sh
			Export de LV existant dans targetcli.

		Les LUNs seront visibles pour le client (initiator)

	4)	aller sur le client pour mapper les LUNs (cf ../disk)

Scripts divers
==============
	1) create_lv.sh
		Création de 1 ou plusieurs LVs dans un VG.
		Ce scripts s'assure que les normes sont respectées.
		Est utilisé par les scripts ci dessus

	2) remove_lv.sh
		Suppression de 1 ou plusieurs LVs dans un VG.
		L'entête des LVs est effacé.

		Ne fonctionne que pour les LVs crées par create_lv.sh

	3) reset_all_for_db.sh
		Supprime le ou les initiators pour une base, le backstore et
		tous les LVs de la base seront remis à zéro.
	
	4)	delete_intiator.sh
		Supprime un initiator le backstore reste intacte.	

	5)	delete_backstore.sh
		Supprime un backstore, échouera si un initiator utilise un des disques
		du backstore.
		
		Les LVs restent intactes.

License
-------

Copyright 2016 Philippe Leroux  - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)
