Recycler un serveur :
---------------------

_Cette documentation est juste un aide mémoire perso._

Se connecter sur le serveur cible en root :

- cd ~/plescripts/database_server
- ./uninstallall.sh -all	supprime tous les composants.

	Pour ne supprimer que 1 ou plusieurs composant voir l'aide.

- ./revert_to_master.sh -doit

	Repasse sur la configuration du master.
	L'installation peut être refaite depuis le début avec clone_master.sh

	Pour un RAC exécuter ./revert_to_master.sh -doit sur tous les nœuds.

Depuis le poste client, supprimer toutes les traces d'un serveur :

- cd ~/plescripts/database_server
- ./remove_server.sh -db=<str>
- Le DNS et le SAN sont mis à jours.

