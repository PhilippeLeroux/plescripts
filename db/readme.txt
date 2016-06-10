Création d'une base de donnée.
==============================
**Attention : Les scripts sont prévus pour fonctionner sur des VMs de démo, en
aucun cas ils ne doivent être utilisés sur des serveurs d'entrepises.**

1. Se connecter sur le serveur : `ssh oracle@srvbabar01`

2. Ce déplacer dans le répertoire plescripts/db : `cd plescripts/db`

3. Pour créer une base de données exécuter le script create_db.sh :
`./create_db.sh -name=babar`

	La base sera de type "Container Database", pour créer une base ala 11gR2 utiliser
	l'option -cdb=no

	Exemple `./create_db.sh -name=babar -cdb=no`

4. Pour créer une "Plugin Database" utiliser le paramètre -pdbName

	Exemple : `./create_db.sh -name=babar -pdbName=babar01`

5. Pour visualiser le fichier 'alert.log' durant la création utilser le paramètre -verbose

	Exemple : `./create_db.sh -name=babar -pdbName=babar01 -verbose`


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
