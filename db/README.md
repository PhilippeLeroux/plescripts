**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entreprises. Les scripts
sont très loin des exigences d'une entreprise.**

--------------------------------------------------------------------------------

Création d'une base de donnée.
==============================

1. Se connecter sur le serveur : `ssh oracle@srvbabar01`

2. Ce déplacer dans le répertoire plescripts/db : `cd plescripts/db`

3. Pour créer une base de données exécuter le script create_db.sh :
	
	`./create_db.sh -name=babar -pdbName=babar01`

	La base sera de type "Container Database", pour créer une base ala 11gR2 utiliser
	l'option -cdb=no

	Pour visualiser le fichier 'alert.log' durant la création ajouter le paramètre -verbose

	Exemple : `./create_db.sh -name=babar -pdbName=babar01 -verbose`

- Les bases sont crées avec l'option threaded_execution=true, pour se connecter
avec le compte sys il faut donc utiliser la syntaxe : `sqlplus sys/Oracle12 as sysbda`

	Il en va de même pour rman & co.

- Les bases sont crées en 'archive log'

- Une fois le script terminé le statue de la base est affichée (exemple d'une base SINGLE) :

TODO : Créer un service pour la pdb

```
# ==============================================================================
# Database config :
22h24> srvctl config database -db babar
Database unique name: BABAR
Database name: BABAR
Oracle home: /u01/app/oracle/12.1.0.2/dbhome_1
Oracle user: oracle
Spfile: +DATA/BABAR/PARAMETERFILE/spfile.269.914192133
Password file: 
Domain: 
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Disk Groups: FRA,DATA
Services: 
OSDBA group: 
OSOPER group: 
Database instance: BABAR

# ==============================================================================
22h24> crsctl stat res ora.babar.db -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.babar.db
      1        ONLINE  ONLINE       srvbabar01               Open,STABLE
--------------------------------------------------------------------------------
```

- Pour se connecter au serveur : `ssh oracle@srvbabar01`

	Pour utiliser le compte grid depuis le compte oracle pas besoin de mot de passe :
```
oracle@srvbabar01:BABAR:oracle> sugrid
grid@srvbabar01:+ASM:grid> asmcmd lsdg
State    Type    Rebal  Sector  Block       AU  Total_MB  Free_MB  Req_mir_free_MB  Usable_file_MB  Offline_disks  Voting_files  Name
MOUNTED  EXTERN  N         512   4096  1048576     32752    27479                0           27479              0             N  DATA/
MOUNTED  EXTERN  N         512   4096  1048576     32752    31117                0           31117              0             N  FRA/
```

--------------------------------------------------------------------------------

License
-------

Copyright (©) 2016 Philippe Leroux - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
