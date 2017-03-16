./test_guestadditions.sh -host=name
	retourne 0 si les Guest Additions sont à jour, sinon retourne 1

./attach_iso_guestadditions.sh -vm_name=name
	Attache l'ISO des Guests sur la VM, télécharge, si besoins, l'ISO.

Après avoir attaché l'ISO, exécuter sur le serveur :
	- install_guestadditions.sh

J'ai effectué plusieurs tests et les Guest Additions n'apportent rien de bons et les
performances des bases sont moins bonnes.
De plus il est impératif d'utiliser ntp avec le RAC.


Donc les serveurs RAC utilisent ntp, les serveurs standalone chrony.
