**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------
# Objectif.
Ces scripts servent à créer les 2 VMs K2 et orclmaster.

Pour des raisons pratique mettre le répertoire ~/plescripts/shell dans le PATH :

	export PATH=$PATH:~/plescripts/shell
--------------------------------------------------------------------------------

# Création des VMs.

* TODO : parler de ~/plescripts/global.cfg 

* `cd ~/plescripts/setup_first_vms/vbox_scripts`

* Exécuter : `./create_master_vm.sh`

TODO : insérer screenshots

* Exécuter : `./create_infra_vm.sh`

TODO : insérer screenshots
	
* Configuration de la VM master : 
```
VBoxManage startvm orclmaster --type headless
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
