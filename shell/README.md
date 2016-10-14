- clean_log

	Permet de supprimer les caractères de controles dans les logs.

	Est utilisé par vimL

- make_ssh_user_equivalence_with.sh

	Établie une connexion ssh sans mot de passe entre le poste client et un serveur.

- gen_docs.sh

	génération d'une doc pour mes scripts 'lib'

	N'est plus vraiment utilisé.

- grid_logs : standalone ou RAC 2 nœuds

	Effectue 2 connexions par serveurs
	*	Les 2 terminaux du haut affichent l'alerte de l'agent.
	*	Les 2 terminaux du bas affichent l'alerte ASM.

	[screen]([[https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/grid_logs.png)

- llog

	Affiche les dernières logs

- monitor_san.sh [db] ou base définie par set_db

	Affiche les IOs disques correspondant à une base RAC ou SINGLE.

- monitor_server.sh [db]  ou base définie par set_db

	Exécute le script tmux_monitor_server.sh avec le/les noms de serveur(s)
	correspondant à une base dans un xterm en plein écran.

- oracle_logs -db=<str>	ou base définie par set_db

	Afficher les fichiers d'alerte d'une base en RAC.

	[screen]([[https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/oracle_logs.png)

- show_grid_status -db=<str> ou base définie par set_db

	Appel de crsclt stat res -t sur le premièr serveur.

- start_vm [vm_name] ou serveur(s) de base définie par set_db

	Démarre la VM vm_name, le nom peut être incomplet.

- stop_vm [vm_name]  ou serveur(s) de base définie par set_db

	Stop la VM vm_name, le nom peut être incomplet.

- tmux_monitor_server.sh

	Lance vmstat et top dans 2 terminaux multiplexés, il y en a 4 pour un RAC 2 noeuds.

	[screen]([[https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/tmux_monitor_server.png)

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
