**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

### Objectifs :

Description de la configuration du poste client.

### Description des scripts :

* apply_myconfig.sh

  Met à jour la configuration du poste client en effectuant les actions suivantes :

  * bashrc_extensions : copier en ~/.bashrc_extensions puis ajouté à la fin de .bashrc

  * mytmux.conf : copier en ~/.tmux.conf

  * myvimrc : copier en ~/.vimrc

  * vimtips : copier en ~/.vimtips

* Ajouter dans PATH : ~/plescripts/shell puis exécuter vim_plugin -init

	Tous les plugins vim seront installés.

* suse_dir_colors fichier copier sur les comptes des serveurs Oracle.

* enable_nfs_server.sh : à exécuter si utilisation des partages NFS.

* confiration_poste_client.odt : screenshot sur la configuration réseau sur opensuse.

* Misc
  * configurations.txt divers trucs.
