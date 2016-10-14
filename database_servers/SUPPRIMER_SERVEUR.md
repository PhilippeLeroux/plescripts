Depuis le poste client, supprimer totalement un serveur :
```
cd ~/plescripts/database_servers
./clean_up_infra.sh -db=daisy
```
Le DNS et le SAN sont mis à jours et les VMs sont supprimées.
