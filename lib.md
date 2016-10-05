# Description des lib utilisées.

## cfglib.sh
Permet de lire le contenu des fichiers ~/plescripts/database_servers/${DB}/node*.

L'objectif étant d'être indépendant du format décrivant la plateforme et de ne
plus parser le fichier dans plusieurs scriptes.

À généraliser.

## dblib.sh
Exécuter des commandes via sqlplus.

Chaque commande est affichée avant sont exécution.

## disklib.sh
Fonction permettant d'obtenir des informations sur les devices.

TODO : Faire le ménage.

## gilib.sh
Grid Infra lib, permet d'exécuter une commande sur tous les nœuds d'un RAC.

## misclib.sh
Contient toutes les fonctions de plelib.sh qui ne sont plus utilisées.

## networklib.sh
Contient des fonctions permettant d'obtenir des informations sur la configuration réseau.

## plelib.sh
Lib principale, contient un grand nombre de fonctions génériques.
