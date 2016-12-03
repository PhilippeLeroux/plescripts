### Description des scripts :

* Script myconfig.sh

  * Avec le paramètre -apply met à jour la configuration du poste client en
  effectuant les actions suivantes :

	* bashrc_extensions : copier en ~/.bashrc_extensions puis ajouté à la fin de .bashrc

		Contient par exemple la fonction set_db permet de definir la base sur
		laquelle on travaille.
		`set_db daisy` indique que l'identifiant par défaut est daisy, les alias
		suivant permettent de se connecter facilement :
		 - oracle : se connectera sur le serveur srvdaisy01 avec le compte oracle.
		 - grid : se connectera sur le serveur srvdaisy01 avec le compte grid.
		 - root : se connectera sur le serveur srvdaisy01 avec le compte root.

		Utiliser le paramètre 2 pour aller sur le second nœud ex : `oracle 2`

		Certaines commandes n'ont plus besoins du paramètre -db :
		  - start_vm [2]
		  - stop_vm [2]
		  - show_grid_status [2]
		  - grid_logs
		  - oracle_logs
		  - etc (La pluspart des scripts dans ~/plescripts/shell)

	* mytmux.conf : copier en ~/.tmux.conf

	* application configuration vim

  * Avec le paramètre -backup effectue une sauvegarde de mes fichiers de configuration :
	* Backup de .bashrc_extensions
	* Exécute vim_config.sh -backup
	* Backup de ~/.tmux.conf

--------------------------------------------------------------------------------

* Ajouter dans PATH : ~/plescripts/shell puis exécuter vim_plugin -init

* suse_dir_colors fichier copier sur les comptes des serveurs Oracle.

* enable_nfs_server.sh : à exécuter si utilisation des partages NFS.

* confiration_poste_client.odt : screenshot sur la configuration réseau sur opensuse.

* Misc
  configurations.txt divers trucs.
