##	Configuration d'un serveur de temps

### Problèmes rencontrés avec Linux 7
* chrony

	À partir de Linux 7 `chrony` est installé par défaut, pour pouvoir utiliser
	le démon `ntpd` il faut désinstaller `chronyd`, sinon la configuration de `ntp`
	se déroule correctement mais au démarrage de l'OS il y aura conflit entre les
	2 démons.

###	Description des scripts

Le démon `ntp` est maintenant utilisé par défaut, pour basculer sur l'un ou l'autre
dès démons ajuster la variable `ntp_tool` du fichier `global.cfg`

* configure_chrony.sh

	Configure le service `chrony`, utilisé sur le serveur d'infra.

* configure_ntp.sh

	Configure le service `ntp`.

	Avant d'utiliser ce script :
	* `chrony` doit avoir été supprimé de l'OS
	* `ntp` doit avoir été installé.

	L'outil `cluvfy` d'Oracle retourne une erreur sur la synchro hardware, pourtant
	elle est configurée au niveau de `ntp`.

	Je pense que c'est un bug Oracle, [la doc Redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Configuring_the_Date_and_Time-hwclock.html)
	précise un changement de comportement entre Linux 6 et 7. Avec Linux 7 le
	'hardware clock' est synchronisé toutes les 11mn par le kernel, avant c'était
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
