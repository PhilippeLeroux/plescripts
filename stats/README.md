# Contient divers scripts faisant des mesures statistiques

## gnuplot
J'ai très peu de maîtrise de gnuplot, son langage et à la fois simple et complexe.

## Scripts stables (ou pas)
* memstats.sh : Capture des statistiques sur la consommation mémoire.
* memplot.sh : Affiche avec gnuplot les stats produites par memstats.sh
* create_service_memory_stats.sh : Créé et active un service systemd permettant
de lancer/arrêter memstats.sh en démarrage/arrêt du serveur.

## Scripts bêta
* ifstats.sh : Capture des statistiques sur le débit d'une carte.
* ifplots.sh : Affiche avec gnuplot les stats produites par ifstats.sh

ifplots.sh affiche, par défaut, les 5 dernières minutes ce qui rend les graphs
plus lisible : ![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/ifplot.png)
Pour changer l'intervalle utiliser le paramètre -range_mn=8

## Services
A la création du serveur sont créés 2 ou 3 services pour mesurer des statistiques :
* plememstats		stats sur l'ocuppation mémoire.
* pleiscsistats		stats sur l'interco iSCSI.
* pleifracstats		stats sur l'interco RAC.

Par défaut les services ne sont pas activés.

Pour démarrer un service, se connecter `root` sur le serveur et exécuter la
commande :
```
systemctl start plememstats
```
Changer le nom du service pour démarrer les autres services.

Pour activer un service au démarrag, se connecter `root` sur le serveur et
exécuter la commande :
```
systemctl enable plememstats
```
Changer le nom du service pour démarrer les autres services.

La variable `PLESTATISTICS` du fichier `global.cfg` permet de définir les services
à activer durant l'installation.

Si la variable `PLE_STATISTICS` est exportée avant l'exécution du script de clonage
elle prévaut sur la variable `PLESTATISTICS`.

Les valeurs possibles sont :
*	DISABLE	les services ne sont pas activés.
*	IFISCSI	statistiques sur l'interco iSCSI.
*	IFRAC   statistiques sur l'interco RAC.
*	MEMORY  statistiques sur la consomation mémoire.

Pour activer toutes les statistiques :
```
export PLE_STATISTICS="IFISCSI IFRAC MEMORY"
```
