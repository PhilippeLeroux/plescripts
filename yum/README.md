* sync_oracle_repository.sh ne doit être exécuté que sur le serveur d'infra.
	- Création : duplique les CDs et se synchronise puis export NFS du repo.

	  passer le paramètre -copy_iso_path=...

	- Synchro : synchronise le repo Oracle Linux

	  C'est le mode de fonctionnement par défaut.

* public-yum-ol7.repo
	- Doit être déployé sur tous les serveurs.
	- Tous les serveurs doivent monter l'export sur /mnt/yum
