#	Création d'un dataguard.

##	Pré requis.
 - Créer 2 serveurs, ex : srvdaisy01 & srvdonald01
 - Créer une base sur le serveur daisy.
 
## Création.
 - Sur le poster client aller dans le répertoire `~/plescripts/db/stby`

 - Etablir l'équivalence ssh entre les comptes oracle des 2 serveurs.

   Exécuter la commande :

   `./00_setup_equivalence.sh -server1=srvdaisy01 -server2=srvdonald01 -user1=oracle`

 - Se connecter avec le compte oracle sur le serveur srvdaisy01 et aller dans le répertoire : `~/plescripts/db/stby`

 - Exécuter le script :

   `./setup_config.sh -primary=daisy -standby=donald -standby_host=srvdonald01`

##	Prochaine étape 
 Mise en oeuvre des services pour effectuer les bascules.

##	Prochaine étape après la prochaine étape.
 L'observeur : sur K2 ??

##	Remarques :
 * Arrêter les 2 serveurs;
 * Démarrer le serveur de la standby
 * Une fois la standby totalement démarré démarré le serveur de la primary.

=====> La standby ne démarrera jamais.
