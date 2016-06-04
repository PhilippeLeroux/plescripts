http://lea-linux.org/documentations/Fiches:Administration-fichewakeonlan
[root@racaaa01 ~]# ethtool enp0s8
Settings for enp0s8:
        Supported ports: [ TP ]
        Supported link modes:   10baseT/Half 10baseT/Full 
                                100baseT/Half 100baseT/Full 
                                1000baseT/Full 
        Supported pause frame use: No
        Supports auto-negotiation: Yes
        Advertised link modes:  10baseT/Half 10baseT/Full 
                                100baseT/Half 100baseT/Full 
                                1000baseT/Full 
        Advertised pause frame use: No
        Advertised auto-negotiation: Yes
        Speed: 1000Mb/s
        Duplex: Full
        Port: Twisted Pair
        PHYAD: 0
        Transceiver: internal
        Auto-negotiation: on
        MDI-X: off (auto)
        Supports Wake-on: umbg							
        Wake-on: d									<=== doit valoir g pour être bootable.
        Current message level: 0x00000007 (7)
                               drv probe link
        Link detected: yes


root@racaaa01 ~]# ethtool -s enp0s8 wol g
Cannot set new wake-on-lan settings: Operation not supported
  not setting wol

====>  Virtualbox n'implémente pas encore la fonctionalité !

root@racaaa01 ~]# ip link sho enp0s8
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether 08:00:27:37:2d:d0 brd ff:ff:ff:ff:ff:ff

Depuis machine distante :
etherwake -i enp0s8 08:00:27:37:2d:d0

ethtool -i eth1

License
-------

Copyright 2016 Philippe Leroux  - All Rights Reserved

This project including all of its source files is released under the terms of [GNU General Public License (version 3 or later)](http://www.gnu.org/licenses/gpl.txt)
