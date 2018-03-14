[English translation](https://github.com/PhilippeLeroux/plescripts/wiki/english)

### Objectifs :
Simuler une infrastructure de VMs pour créer des serveurs de base de données
dans les conditions proches de ce que l'on peut trouver en entreprise.

Le serveur central se nomme K2 et a en charge :
- la gestion du DNS via bind.
- la gestion du DHCP, principallement pour intégrer facilement des VM de types 'desktop'.
- la gateway qui centralise l'accès à internet des serveurs, par défaut aucun
serveur de base de données ne peut accéder à internet. Le firewall et SELinux sont
activés sur ce serveur.
- la gestion du dépôt logiciel Oracle, pour la mise à jour des serveurs de base de données.
- de synchroniser l'horloge des serveurs de base de données, si le PC exécutant
Virtual Box n'a pas de serveur NTP.

Type de serveurs de base de données pouvant être créé :
- Base de données sur un serveur standalone (sur ASM ou filesystem).
- Base de données en RAC (pas de RAC étendue, uniquement MAA)
- Mise en dataguard de 2 serveurs standalone (sur ASM ou filesystem).

Versions logiciels :
- VirtualBox version minimum 5.1
- Oracle Linux 7.4 est utilisé pour les serveurs base de données et le serveur d'infrastructure.
- Oracle 12cR1 base SINGLE et RAC.
- Oracle 12cR2 base SINGLE et RAC EE ou SE2.

La création des serveurs de base de données est 100% automatisée, il n'y a pas
besoins de connaissances particulières sur la gestion d'un DNS ou d'un SAN.

Le poste exécutant VirtualBox doit avoir au minimum 8Gb de RAM, pour un RAC 12cR2
prévoir 16Gb.

Les scripts fonctionnent sous Linux uniquement, ils ont été testés sous openSUSE.

--------------------------------------------------------------------------------

### Instructions

[Configuration du poste exécutant VirtualBox.](https://github.com/PhilippeLeroux/plescripts/wiki/Configuration-du-virtual-host)

[Création des serveurs d'infrastructure.](https://github.com/PhilippeLeroux/plescripts/wiki/Création-des-VMs-orclmaster-et-K2)

[Création des serveurs de base de données.](https://github.com/PhilippeLeroux/plescripts/wiki/Create-servers)

--------------------------------------------------------------------------------

![Screenshot](https://github.com/PhilippeLeroux/plescripts/wiki/virtualbox_manager.png)

--------------------------------------------------------------------------------

### LICENCE

Copyright © 2016,2017,2018 Philippe Leroux <philippe.lrx@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
