### Liste des équivalences ssh.

L'utilisateur local du client/serveur host a une équivalence avec les comptes root des
VMs :
* K2
* nfsorclmaster

nfsorclmaster est cloné pour tout nouveau serveur Oracle, le fichier 'know_host'
est mis à jour pour que l'équivalence reste valide.

Lors de la configuration du serveur Oracle une équivalence ssh est établie entre
l'utilisateur local du client/serveur host avec les comptes oracle et grid.

Liste des équivalences ssh :

* L'utilisateur local peut se connecter sans mot de passe sur toutes les VMs de
base de données aux utilisateurs root, grid et oracle et au compte root de K2.

* Dans le cas de VMs constituant les nœuds d'un RAC les utilisateurs root, grid et
oracle ont tous des équivalences entre eux.

* Dans le cas de 2 serveurs standalones mis en dataguard les comptes oracle ont une
équivalence ssh entre eux.

* Le compte root de toutes les VMs de base de données a une équivalence ssh avec
le compte root du serveur K2.

### Description des scripts.

*	make_ssh_equi_with_all_users_of.sh

	Effectue les équivalences SSH entre l'utilisateur local et les comptes root,
	grid et oracle d'un serveur.

	Doit être exécuté depuis le client/serveur host.

*	make_ssh_user_equivalence_with.sh

	Effectue l'équivalence SSH entre l'utilisateur local et l'utilisateur d'un
	autre serveur.

*	setup_ssh_equivalence.sh

	Effectue les équivalences SSH entre un utilisateur de 2 VMs.

	Le script doit être lancé depuis le client/serveur host qui a déjà une équivalence
	avec l'utilisateur root des 2 VMs. Aucun mot de passe ne sera donc demandé.

*	setup_rac_ssh_equivalence.sh

	Effectue toutes les équivalences SSH pour les utilisateurs root, grid et oracle
	nécessaires pour des VMs en RAC.
	
	Le script doit être lancé depuis le client/serveur host qui a déjà une équivalence
	avec l'utilisateur root des 2 VMs. Aucun mot de passe ne sera donc demandé.


*	ssh_equi_cluster_rac.sh

	Effectue les équivalences SSH entre les utilisateurs root, grid et oracle.

	Doit être exécuté avec le compte root sur la VM. Seul le mot de passe root
	sera demandé.

	Le script doit être exécuté depuis tous les noeuds d'un RAC.

*	remove_files_from_ssh_directory.sh

	Efface le répertoire .ssh des utilisateurs root, grid et oracle d'une VM.

	Doit être exécuté avec le compte root de la VM.

*	remove_ssh_auth_for.sh

	Supprime les équivalences SSH pour les utilisateurs root, grid et oracle.

	Doit être exécuté depuis le client/serveur host.

*	cleaning_known_hosts.sh

	Nettoie le fichier .know_hosts du client/serveur host. Compare les serveurs
	présents dans .know_hosts et le DNS, si un serveur est présent dans .know_hosts
	mais pas dans le DNS il est alors supprimé de .know_hosts.
