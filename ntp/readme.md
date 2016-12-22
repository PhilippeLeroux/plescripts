##	Configuration d'un serveur de temps

### Problèmes rencontrés avec Linux 7
* chrony

	À partir de Linux 7 `chrony` est installé par défaut, pour pouvoir utiliser
	le démon `ntpd` il faut désinstaller `chronyd`, sinon la configuration de `ntp`
	se déroule correctement mais au démarrage de l'OS il y aura conflit entre les
	2 démons.

* ntp

	Fonctionne très mal sur des VMs, au démarrage de la VM l'OS a plus de 1 seconde
	d'avance et le temps fait des sauts brutaux de 3 à 10 secondes.

	Pour que `ntp` fonctionne bien il faut désactiver `kvmclock` au niveau de
	l'os 'Guest'. Voir le script `disable_kvmclock.sh`

* Synchro par VBox

	Synchroniser par VBox n'est pas une bonne idée, il ne contre pas la dérive du
	temps mais ajuste périodiquement l'heure du guest.

	Par exemple :
	```
	VBoxManage guestproperty set <VM NAME> "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold" 1
	```
	n'est pas une bonne idée. De plus il est nécessaire de compiler les 'Guest Additions'
	à chaque mise à jour du noyau.

Description du problème du temp [par RedHat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Virtualization_Deployment_and_Administration_Guide/chap-KVM_guest_timing_management.html)

###	Description des scripts

* configure_chrony.sh

	Configure le service `chrony`, utilisé sur le serveur d'infra et les VMs
	standalone.

* configure_ntp.sh

	Configure le service `ntp` pour les VMs en RAC.

	L'outil `cluvfy` d'Oracle retourne une erreur sur la synchro hardware, pourtant
	elle est configurée au niveau de `ntp`.

	Je pense que c'est un bug Oracle, [la doc Redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Configuring_the_Date_and_Time-hwclock.html)
	précise un changement de comportement entre Linux 6 et 7. Avec Linux 7 le
	'hardware clock' est synchronisé toutes les 11 mn par le kernel, avant c'était
	fait par des scripts d'init à l'arrêt et au démarrage du serveur.

## Aide-mémoire

### ntp
[Documentation redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/s1-Configure_ntpdate_Servers.html)

* ntpq -p : permet de visualiser la configuration.

* ntpdate K2 : permet de synchroniser manuellement le serveur si l'offset retourné
par `ntpq -p` est trop important.

###	Chrony
* chronyc sources
* chronyc tracking
* chronyc sourcestats
