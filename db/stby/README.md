#	Création d'un dataguard.

##	Pré requis.
 - [Créer 2 serveurs, ex : srvdaisy01 & srvdonald01.](https://github.com/PhilippeLeroux/plescripts/tree/master/database_servers/README.md)
 - [Créer une base sur le serveur daisy.](https://github.com/PhilippeLeroux/plescripts/tree/master/db/README.md)
 
## Création d'une standby sur le serveur srvdonald01.
 - Sur le poster client aller dans le répertoire `~/plescripts/db/stby`

 - Etablir l'équivalence ssh entre les comptes oracle des 2 serveurs.

   Exécuter la commande :

   `./00_setup_equivalence.sh -server1=srvdaisy01 -server2=srvdonald01 -user1=oracle`

 - Se connecter avec le compte oracle sur le serveur srvdaisy01 et aller dans le répertoire : `~/plescripts/db/stby`

 - Exécuter le script :

   `./create_dataguard.sh -primary=daisy -standby=donald -standby_host=srvdonald01`

##	Prochaine étape : tester la bascule. 
 Les services oci sont mis en oeuvres. Faire les services java.
 Tester les bascules.

##	Prochaine étape après la prochaine étape.
 L'observeur : sur K2 ??

##	Remarques :
 * Arrêter les 2 serveurs;
 * Démarrer le serveur de la standby
 * Une fois la standby totalement démarré démarré le serveur de la primary.

=====> La standby ne démarrera jamais, je ne l'avais jamais remarqué.
