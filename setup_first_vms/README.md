**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

Ces scripts servent à créer les 2 VMs K2 et orclmaster.

* Création des VMs

	* TODO : parler de ~/plescripts/global.cfg 

	* `cd ~/plescripts/setup_first_vms/vbox_scripts`

	* Exécuter : `./create_master_vm.sh`

		Configuration réseau : 192.170.100.2/24
	
		Host name : orclmaster

		TODO : insérer screenshots

	* Exécuter : `./create_infra_vm.sh`
	
	* Démarrer la VM master : orclmaster.
	```VBoxManage startvm orclmaster --type headless
	wait_server orclmaster
	ssh root@orclmaster
	mkdir /mnt/plescripts
	mount 192.170.100.1:/home/kangs/plescripts /mnt/plescripts
	ln -s /mnt/plescripts ./plescripts
	cd plescripts/setup_first_vms/
	./02_update_config.sh
	./03_setup_infra_or_master.sh -role=master
	poweroff
	```
--------------------------------------------------------------------------------
