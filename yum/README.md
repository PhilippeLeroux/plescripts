* sync_oracle_repository.sh ne doit être exécuté que sur le serveur d'infra.
	- Création : duplique les CDs et se synchronise puis export NFS du repo.

	  passer le paramètre -copy_iso_path=...

	- Synchro : synchronise le repo Oracle Linux

	  C'est le mode de fonctionnement par défaut.

* disable_net_repository.sh désactive l'accès au dépôt internet.

* clone_yum_repository.sh
  - Clone le repository OL7 sur K2.
  - Met à jour le master.

  Si des serveurs existent, il faut exécuter le script `disable_net_repository.sh` pour
  qu'ils prennent en compte le repo sur K2

* public-yum-ol7.repo
	- Doit être déployé sur tous les serveurs.
	- Tous les serveurs doivent monter l'export sur /mnt/yum
