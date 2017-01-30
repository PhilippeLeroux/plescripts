##	Configuration d'un serveur de temps

### Problèmes rencontrés avec Linux 7

Les problèmes décrient sont particulièrement visible si le virtual-host a peu
de CPUs.

* chrony

	À partir de Linux 7 `chrony` est installé par défaut, pour pouvoir utiliser
	le démon `ntpd` il faut désinstaller `chronyd`, sinon la configuration de `ntp`
	se déroule correctement mais au démarrage de l'OS il y aura conflit entre les
	2 démons.

* ntp

	Fonctionne très mal sur des VMs si le virtual-host est peu puissant, au
	démarrage de la VM l'OS a plus de 1 seconde d'avance et le temps fait des
	sauts brutaux de 3 à 10 secondes.

	Pour que `ntp` fonctionne bien il faut désactiver `kvmclock` au niveau de
	l'os 'Guest', voir le script `disable_kvmclock.sh` et mettre en place le
	script `force_sync_ntp.sh` qui ajustera `ntp` si la dérive atteint 1 ms.

* Synchro par VBox

	Synchroniser par VBox n'est pas une bonne idée, il ne contre pas la dérive du
	temps mais ajuste périodiquement l'heure du guest.

	Par exemple :
	```
	VBoxManage guestproperty set <VM NAME> "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold" 1
	```
	N'est pas une bonne idée, il y aura constamment des 'timeout'. (De plus il est
	nécessaire de compiler les 'Guest Additions' à chaque mise à jour du noyau.)

Description du problème du temps [par RedHat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-KVM_guest_timing_management.html)

###	Description des scripts

* configure_chrony.sh

	Configure le service `chrony`, utilisé sur le serveur d'infra et les VMs
	standalone.

* configure_ntp.sh

	Configure le service `ntp` pour les VMs en RAC.

	Pour ne pas utiliser `ntp` mais `chrony` exporter la variable `RAC_NTP=chrony`
	avant d'exécuter les scripts `clone_master.sh`.

	Avec `ntp` les serveurs consomment plus de ressources CPU sur le virtual-host,
	mais certaines commandes de base de données sont plus performantes de 10 à 30 %
	de gains.

	Utiliser `ocfs2` pour l'`ORACLE_HOME` augmentera les problèmes sur un
	virtual-host peut puissant, il faut davantage de ressources pour faire
	fonctionner le cluster `ocfs2`. Quand `ocfs2` est utilisé il peut y avoir
	des sauts de 15 ms par minute alors que sans le maximum observé est de 1 ms.

	L'outil `cluvfy` d'Oracle retourne une erreur sur la synchro hardware.
	Je pense que c'est un bug Oracle, [la doc Redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Configuring_the_Date_and_Time-hwclock.html)
	précise un changement de comportement entre Linux 6 et 7. Avec Linux 7 le
	'hardware clock' est synchronisé toutes les 11 mn par le kernel, avant c'était
	fait par des scripts d'init à l'arrêt et au démarrage du serveur.

## Aide-mémoire

### ntp
[Documentation redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/s1-Configure_ntpdate_Servers.html)

* ntpq -p : pour visualiser la synchronisation.

* clockdiff : permet de visualiser l'écart de temps entre 2 serveurs.

* ntpdate K2 : permet de synchroniser manuellement le serveur si l'offset retourné
par `ntpq -p` est trop important.

###	Chrony
* chronyc sources : pour visualiser la synchro.
* chronyc tracking
* chronyc sourcestats : pour visualiser l'offset.
