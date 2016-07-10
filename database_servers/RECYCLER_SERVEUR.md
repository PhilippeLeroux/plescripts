Recycler un serveur :
---------------------

_Cette documentation est juste un aide-mémoire._

Se connecter sur le serveur cible en root :

- cd ~/plescripts/database_server

- ./uninstallall.sh -all	supprime tous les composants.

	Pour ne supprimer que 1 ou plusieurs composants spécifiques voir l'aide : `./uninstallall.sh -h`

- ./revert_to_master.sh -doit

	Repasse sur la configuration du master.
	L'installation peut être refaite depuis le début avec clone_master.sh

	Pour un RAC exécuter ./revert_to_master.sh -doit sur tous les nœuds.

	Détaille des actions effectuées par le scripts : `./revert_to_master.sh -h`

Depuis le poste client, supprimer toutes les traces d'un serveur :
- cd ~/plescripts/database_servers

- ./remove_server.sh -db=<str>

- Le DNS et le SAN sont mis à jours.
