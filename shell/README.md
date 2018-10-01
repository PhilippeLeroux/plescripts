- clean_log

	Permet de supprimer les caractères de controles dans les logs.

	Est utilisé par vim

- make_ssh_user_equivalence_with.sh

	Établie une connexion ssh sans mot de passe entre le poste client et un serveur.

- gen_markdown_docs.sh

	* Génération d'une doc au format markdown pour mes scripts `*lib.sh`.
	* La documentation est accessible sur le wiki.
	* Le script peut être utilisé sur n'importe quel script, si les conventions
	pour les commentaires et déclaration de fonctions sont respectées.

	Aide : `gen_markdown_docs.sh -h`

- grid_logs : standalone ou RAC 2 nœuds

	Effectue 2 connexions par serveurs
	*	Les 2 terminaux du haut affichent l'alerte de l'agent.
	*	Les 2 terminaux du bas affichent l'alerte ASM.

	![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/grid_logs.png)

- oracle_logs -db=<str>	ou base définie par set_db

	Visualiser le fichier d'alertlog Oracle :
	* Pour un RAC l'alertlog du serveur 1 est en haut et l'alertlog du serveur 2 en bas.
	* Si la base est en Dataguard le fichier de log du broker est affiché en dessous de l'alertlog de la base.

	![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/oracle_logs.png)

- llog

	Affiche les dernières logs

- monitor_san.sh [db] ou base définie par set_db

	Affiche les IOs disques correspondant à une base RAC ou SINGLE depuis le serveur d'infra.

- monitor_server.sh [db]  ou base définie par set_db

	Exécute le script tmux_monitor_server.sh avec le/les noms de serveur(s)	correspondant à une base dans un xterm en plein écran.
	
	Pour un RAC 2 nœuds lance vmstat et top dans 4 terminaux multiplexés.
	![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/tmux_monitor_server_rac.png)
	
	Pour un Single affiche les IOs puis vmstat et top.
	![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/tmux_monitor_server_single.png)

- monitor_io_rac.sh ne prend pas de paramètre, se base uniquement sur set_db
	
	Exécute le script tmux_io_rac.sh qui affiche les IOs des 2 serveurs.
	
	![screen](https://github.com/PhilippeLeroux/plescripts/wiki/screens_scripts_shell/monitor_io_rac.png)
	
- lscrs -db=<str> ou base définie par set_db

	Appel de crsclt stat res -t, dans le cas d'un RAC utilise l'adresse de SCAN.

- start_vm [vm_name] ou serveur(s) de base définie par set_db

	Démarre la VM vm_name, le nom peut être incomplet.

- stop_vm [vm_name]  ou serveur(s) de base définie par set_db

	Stop la VM vm_name, le nom peut être incomplet.

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
