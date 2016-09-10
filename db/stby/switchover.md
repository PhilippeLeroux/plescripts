```
oracle@srvsaturn01:ARIANE:12c> dgmgrl
DGMGRL for Linux: Version 12.1.0.2.0 - 64bit Production

Copyright (c) 2000, 2013, Oracle. All rights reserved.

Welcome to DGMGRL, type "help" for information.
DGMGRL> connect sys/Oracle12
Connected as SYSDBA.
DGMGRL> show configuration

Configuration - PRODCONF

  Protection Mode: MaxPerformance
  Members:
  ariane  - Primary database
    jupiter - Physical standby database

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS   (status updated 25 seconds ago)

DGMGRL> switchover to jupiter;
Performing switchover NOW, please wait...
Operation requires a connection to instance "JUPITER" on database "jupiter"
Connecting to instance "JUPITER"...
Connected as SYSDBA.
New primary database "jupiter" is opening...
Oracle Clusterware is restarting database "ariane" ...
Switchover succeeded, new primary is "jupiter"
DGMGRL> show configuration

Configuration - PRODCONF

  Protection Mode: MaxPerformance
  Members:
  jupiter - Primary database
    ariane  - Physical standby database

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS   (status updated 141 seconds ago)
```
