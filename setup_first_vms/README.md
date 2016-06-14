**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

Ces scripts servent à créer les 2 VMs K2 et orclmaster.

* Création des VMs

	Le répertoire vbox_scripts contient les scripts permettant de créer le VMs

	* Depuis windows éditer le script createvm.bat pour ajuster le nom des répertoires.

	* Depuis Linux éditer le script ~/plescripts/global.cfg et ajuster les noms
	des répertoires puis exécuter : `01_update_vms_scripts.sh`

--------------------------------------------------------------------------------

Les scripts ci dessous doivent être exécuter depuis la VM avec le compte root

* 02_update_config.sh

	Configure le compte root et met à jour l'OS.

* 03_setup_infra_or_master.sh.sh -role=infra|master

	Configure le serveur en fonction de son rôle

* 04_unzip_oracle_cd.sh

	Extraction des zips oracle & grid
