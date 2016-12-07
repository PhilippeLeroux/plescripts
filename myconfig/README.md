### Description des scripts :

* **Ajouter** à la variable `PATH` le chemin : `~/plescripts/shell`

* VirtualBox doit être installé.

* Le script `~/plescripts/configure_global.cfg.sh` doit avoir été exécuté.

* Un serveur NFS doit être installé, sous opensuze : `sudo zypper install yast2-nfs-server` 

* Description du script myconfig.sh

	Ce script configure mon environnement de travail, il fonctionne correctement
	chez moi avec opensuse, il applique certain dès prés requis décrient [ici](https://github.com/PhilippeLeroux/plescripts/wiki/Cr%C3%A9ation-des-VMs-orclmaster-et-K2).
	Vous pouvez l'exécuter mais je ne **garantis rien**.

	* Avec le paramètre -apply met à jour la configuration du poste depuis lequel
	il est exécuté en effectuant les actions suivantes :

		* Configure `/etc/sudoers` pour que l'utilisateur courant puisse se
		connecter avec le compte `root` sans saisir de mot de passe.

		* Configure le mode `vi` par défaut.

		* bashrc_extensions : copier en ~/.bashrc_extensions puis ajouté à la fin
		de .bashrc

		* installe et configure `GVim` et `git` si la distribution est `opensuse`
		Vous devez installer GVim vous même, si votre distribution n'est pas `opensuse`
		et ensuite, éventuellement, exécuter :
			* `~/plescripts/myconfig/vim_config.sh -apply`
			* `~/plescripts/myconfig/vim_plugin.sh -init`

			Le flag `-skip_vim` empêche l'installation est la configuration de GVim.

		* mytmux.conf : copier en ~/.tmux.conf

		* Applique les `acls` sur le répertoire `~/plescripts`

	* Avec le paramètre -backup effectue une sauvegarde de mes fichiers de
	configurations :
		* Backup de .bashrc_extensions
		* Exécute vim_config.sh -backup
		* Backup de ~/.tmux.conf

* Description du script enable_nfs_server.sh

	Ce script configure mon environnement de travail, il fonctionne correctement
	chez moi avec opensuse, il applique certain dès prés requis décrient [ici](https://github.com/PhilippeLeroux/plescripts/wiki/Cr%C3%A9ation-des-VMs-orclmaster-et-K2).
	Vous pouvez l'exécuter mais je ne **garantis rien**.

	Active et démarre le serveur NFS et exporte les répertoires devant être exportés.

* confiration_poste_client.odt : screenshot sur la configuration réseau sur opensuse.

	Je n'ai pas scripté l'ajout d'un serveur DNS (nameserver) car je suis passé
	par l'interface graphique. Le document est plus un 'pense bête' qu'une documentation.

* Le script `~/plescripts/validate_config.sh` permet de vérifier si la configuration
est conforme.

--------------------------------------------------------------------------------

### Description des fichiers de configuration :

* Description de bashrc_extensions.

	Contient fonction set_db permet de definir la base sur laquelle on travaille.
	`set_db daisy` indique que l'identifiant par défaut est daisy, les alias
	suivant permettent de se connecter facilement aux serveurs :
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

* suse_dir_colors fichier copié sur les comptes des serveurs Oracle.
