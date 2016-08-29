### Recycler un serveur :

Se connecter sur le serveur cible en root, supprimer tous les composants :
```sh
cd ~/plescripts/database_server
./uninstallall.sh -all
```
Les VMs seront reconfigurer comme le master, seul les RPMs ne sont pas supprimés.

Pour ne supprimer que certains composants voir l'aide : `./uninstallall.sh -h`
