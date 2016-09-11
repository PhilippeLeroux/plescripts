#	Création d'un dataguard.
  La standby sera en 'real time apply' et ouverte en lecture seule.

  **Note la FRA est grande mais pas infinie, mettre en place les backups RMAN !**

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

## Description du script : `create_dataguard.sh`
 * Configuration du réseau :
   * Mise à jour du fichier tnsnames.ora pour que les bases puissent se joindre.
   * Ajout d'une entrée statique dans le listener sur les 2 serveurs pour le duplicate.

 * Avant de lancer le duplicate :
   * Copie du fichier password vers la standby.
   * Création du répertoire adump sur la standby.

 * Duplication.

   Le script de duplication est simple car les bases sont en 'Oracle Managed File' et
   sur ASM. Pas besoin de [db|log]_convert.

 * Services.

   Il y a 4 services par instance. Il y a 1 service pour les connexions OCI et 1
   service pour les connexions JAVA. Les 2 autres son leur correspondance pour la
   standby (accès en lecture seul).

   _Note :_ ils n'ont pas été testés.

 * Les swhitchover ont été testés et fonctionnent.

## A re-faire avec screen.
 * Faileover testé par un crash du serveur primaire (poweroff)
   * failover ok
   * reconstruction du dataguard ok
     
     Pour la reconstruction il faut juste penser à supprimer le broker.

##	Prochaine étape après la prochaine étape.
 L'observeur : sur K2 ??
