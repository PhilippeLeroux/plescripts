* sync_oracle_repository.sh ne doit être exécuté que sur le serveur d'infra.

	* -copy_iso :

		Duplique le CD Oracle Linux, le synchronise puis export NFS du dépôt sur
		le réseau public des VMs.

	* -update_repository_file_only :

		Met à jour le fichier public-yum-ol7.repo qui est à utiliser sur les VMs.

	* Pas de paramètre :

		Teste si des mises à jour sont disponibles, si oui met à jour le serveur et
		synchronise le dépôt.

* clone_ol_repository_on_infra_server.sh
  - Clone le repository OL7 sur K2.
  - Met à jour le master.

  **Note :** Ce script n'est pas lancé lors de la création du serveur K2, il faut le faire
  explicitement.

* public-yum-ol7.repo
	- Doit être déployé sur tous les serveurs.
	- Tous les serveurs doivent monter l'export sur /mnt
