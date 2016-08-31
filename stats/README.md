# Contient divers scripts faisant des mesures statistiques

## gnuplot
J'ai très peu de maîtrise de gnuplot, son langage et à la fois simple et complexe.

Pour le moment je n'ai pas mieux.

## Scripts stables (ou pas)
* memstats.sh : Capture des statistiques sur la consommation mémoire.
* memplot.sh : Affiche avec gnuplot les stats produites par memstats.sh
* create_systemd_service_stats.sh : Créé et active un service systemd permettant
de lancer/arrêter memstats.sh en démarrage/arrêt du serveur.

Les scripts m'ont permis de mettre en évidence ce que je soupçonnais. 
Je les garde pour d'éventuelles autres analyses.

## Scripts bêta
* ifstats.sh : Capture des statistiques sur le débit d'une carte.
* ifplots.sh : Affiche avec gnuplot les stats produites par ifstats.sh

Il me paraît évident qu'il me faut une iface pour le RAC et un iface pour les disques.

Donc je vais devoir revoir les scripts de créations :(
