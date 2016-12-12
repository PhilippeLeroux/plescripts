##	Configuration d'un serveur de temps

### Problèmes rencontrés avec Linux 7
* chrony

	À partir de Linux 7 `chrony` est installé par défaut, pour pouvoir utiliser
	le démon `ntpd` il faut désinstaller `chronyd`, sinon la configuration de `ntp`
	se déroule correctement mais au démarrage de l'OS il y aura conflit entre les
	2 démons.

* ntpdate

	Le service `ntpdate` n'est pas activé par défaut, l'offset est donc supérieur
	à 1000ms, le Grid Infra refuse donc de s'installer.
	Il faut donc activer et démarrer le service `ntpdate` pour avoir un offset
	correct.

###	Description des scripts

Le démon `ntp` est maintenant utilisé par défaut, pour basculer sur l'un ou l'autre
dès démons ajuster la variable `ntp_tool` du fichier `global.cfg`

* configure_chrony.sh

	Configure le service `chrony`, ce script n'est plus utilisé mais conservé au
	cas où.

* configure_ntp.sh

	Configure les services `ntpdate` et `ntp`.

	Avant d'utiliser ce script :
	* `chrony` doit avoir été supprimé de l'OS
	* `ntp` doit avoir été installé.
	* `ntpdate` est installé par défaut, le script le configure, l'active et le démarre.

	L'outil `cluvfy` d'Oracle retourne une erreur sur la synchro hardware, pourtant
	elle est configurée au niveau de `ntp` et `ntpdate` ...

## Aide-mémoire

### ntp
[Documentation redhat](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/s1-Configure_ntpdate_Servers.html)

* ntpq -p : permet de visualiser la configuration.

* ntpdate K2 : permet de synchroniser manuellement le serveur si l'offset retourné
par `ntpq -p` est trop important, normalement c'est fait au démarrage si le
service `ntpdate` est activé.


###	Chrony
* chronyc sources
* chronyc tracking
* chronyc sourcestats
