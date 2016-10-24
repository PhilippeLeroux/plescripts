Depuis le poste client, supprimer totalement un serveur :
```
cd ~/plescripts/database_servers
./clean_up_infra.sh -db=daisy
```
Le DNS, le SAN, les fichiers de configurations locaux sont mis à jours et les VMs
sont supprimées.
