- clean_log

	permet de supprimer les caractères de controles dans les logs

- connections_ssh_with.sh

	Établie une connexion ssh sans mot de passe entre le poste client et un serveur.

- gen_docs.sh

	génération d'un doc pour mes scripts 'lib'

- grid_logs : uniquement pour RAC 2 nœuds

	Effectue 2 connexions par serveurs
	*	Les 2 terminaux du haut affichent l'alerte de l'agent.
	*	Les 2 terminaux du bas affichent l'alerte ASM.

- ip_www.sh

	Retourn l'IP internet.

- llog

	Affiche les dernières logs

- monitor_san.sh [db] ou base définie par set_db

	Affiche les IOs disques correspondant à une base RAC ou SINGLE.

- monitor_server.sh [db]  ou base définie par set_db

	Exécute le script tmux_monitor_server.sh avec le/les noms de serveur(s)
	correspondant à une base dans un xterm en plein écran.

- oracle_logs -db=<str>

	Afficher les fichiers d'alerte d'une base en RAC.

- rac_connections

	À utiliser depuis le noeud d'un RAC, utilise tmux pour connecter sur le
	même terminal les 2 noeuds du RAC

- reboot_srv [db] ou base définie par set_db

	Reboot un serveur ou les noeuds d'un cluster RAC

- remove_from_known_host.sh -host=<str>

- set_plymouth_them

	À utiliser sur un serveur : permet de voir les messages au démarrage du serveur.

- show_info_server -db=<str>

	Affiche l'infrastructure correspondant à une base

- show_grid_status [db] ou base définie par set_db

	Appel de crsclt stat res -t sur le premièr serveur.

- shutdown_srv -db=<str> ou base définie par set_db

	Stop le ou les serveurs d'une base.

- start_vm [vm_name]

	Démarre la VM vm_name, le nom peut être incomplet.

- stop_vm [vm_name]

	Stop la VM vm_name, le nom peut être incomplet.

- tmux_monitor_server.sh

	Lance vmstat et top dans 2 terminaux multiplexés, il y en a 4 pour un RAC 2 noeuds.

- update_license_in_readme_files.sh

- vim_plugin

	Permet de gérer mes plugins vim.

- vim_plugin_list.txt

	Utilisé par vim_plugin.
	Tous les plugins dans ce fichier seront (ré)installé par vim_plugin -init

- wait_rac_nodes

	Attend que tous les noeuds d'un RAC soient démarrés.

- wait_server

	Attend qu'un serveur soit démarré.

- where_is_used

	Recherche dans les scripts où est utilisé un mot.

- with

	Fonctionne de pair avec set_db, se connecte sur un serveur avec le compte
	spécifié en paramètre.

	set_db est une fonction définie dans .bashrc_extensions, les allias root, grid
	et oracle sont définies pour utiliser with, exemple :
	```
	> oracle   : se connecte sur le premier serveur.
	> oracle 2 : se connecte sur le second serveur.
	```

