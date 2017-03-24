./test_guestadditions.sh -host=name
	retourne 0 si les Guest Additions sont à jour, sinon retourne 1

Si les Guest ne sont pas installés, les instructions nécessaires pour les
installer sont affichées.

J'ai effectué plusieurs tests et les Guest Additions n'apportent rien de bons et les
performances des bases sont moins bonnes.
De plus il est impératif d'utiliser ntp avec le RAC.

Donc les serveurs RAC utilisent ntp, les serveurs standalone chrony.
