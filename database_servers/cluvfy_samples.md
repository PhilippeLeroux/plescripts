[Documentation Oracle](https://docs.oracle.com/database/121/CWADD/cvu.htm#CWADD1100)

Todo : faire un script qui ne remonte que ce qui est KO ?

Note : peut être utile pour une autre Release.... Mais bon fait chier.

--------------------------------------------------------------------------------

* Avant installation (normalement) :
	```
	grid@srvdonald01:+ASM1:grid> ./runcluvfy.sh comp nodereach -n srvdonald01,srvdonald02 -verbose

	Verifying node reachability

	Checking node reachability...

	Check: Node reachability from node "srvdonald01"
	  Destination Node                      Reachable?
	  ------------------------------------  ------------------------
	  srvdonald01                           yes
	  srvdonald02                           yes
	Result: Node reachability check passed from node "srvdonald01"


	Verification of node reachability was successful.
	```

--------------------------------------------------------------------------------

* Pratiques :
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp freespace

	Verifying Free Space
	The disk free space for file system path "/u01/app/12.1.0.2/grid" is sufficient on all nodes

	Verification of Free Space was successful.
	```

	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp nodeapp -n srvdonald01,srvdonald02 -verbose

	Verifying node application existence

	Checking node application existence...

	Checking existence of VIP node application (required)
	  Node Name     Required                  Running?                  Comment
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald01   yes                       yes                       passed
	  srvdonald02   yes                       yes                       passed
	VIP node application check passed

	Checking existence of NETWORK node application (required)
	  Node Name     Required                  Running?                  Comment
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald01   yes                       yes                       passed
	  srvdonald02   yes                       yes                       passed
	NETWORK node application check passed

	Checking existence of ONS node application (optional)
	  Node Name     Required                  Running?                  Comment
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald01   no                        yes                       passed
	  srvdonald02   no                        yes                       passed
	ONS node application check passed


	Verification of node application existence was successful.
	```

* Vérification de l'OCR.
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp ocr

	Verifying OCR integrity

	Checking OCR integrity...

	Checking the absence of a non-clustered configuration...
	All nodes free of non-clustered, local-only configurations


	Checking daemon liveness...
	Liveness check passed for "CRS daemon"

	Checking OCR config file "/etc/oracle/ocr.loc"...

	OCR config file "/etc/oracle/ocr.loc" check successful


	Disk group for ocr location "+CRS/donald-scan/OCRFILE/registry.255.919376743" is available on all the nodes


	NOTE:
	This check does not verify the integrity of the OCR contents. Execute 'ocrcheck' as a privileged user to verify the contents of OCR.

	OCR integrity check passed

	Verification of OCR integrity was successful.
	```

* OHASD
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp ohasd -n all -verbose

	Verifying OHASD integrity

	Checking OHASD integrity...
	ohasd is running on node "srvdonald01"
	ohasd is running on node "srvdonald02"

	OHASD integrity check passed

	Verification of OHASD integrity was successful.
	```

* Vérification du réseau :
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp nodecon -n all -verbose

	Verifying node connectivity 

	Checking node connectivity...

	Checking hosts config file...
	  Node Name                             Status                  
	  ------------------------------------  ------------------------
	  srvdonald01                           passed                  
	  srvdonald02                           passed                  

	Verification of the hosts config file successful


	Interface information for node "srvdonald01"
	 Name   IP Address      Subnet          Gateway         Def. Gateway    HW Address        MTU   
	 ------ --------------- --------------- --------------- --------------- ----------------- ------
	 eth0   192.170.100.12  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:03:69:B3 1500  
	 eth0   192.170.100.17  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:03:69:B3 1500  
	 eth0   192.170.100.16  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:03:69:B3 1500  
	 eth0   192.170.100.13  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:03:69:B3 1500  
	 eth1   10.10.10.12     10.10.10.0      0.0.0.0         192.170.100.5   08:00:27:E0:B8:BF 9000  
	 eth1   169.254.171.244 169.254.0.0     0.0.0.0         192.170.100.5   08:00:27:E0:B8:BF 9000  


	Interface information for node "srvdonald02"
	 Name   IP Address      Subnet          Gateway         Def. Gateway    HW Address        MTU   
	 ------ --------------- --------------- --------------- --------------- ----------------- ------
	 eth0   192.170.100.14  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:49:B8:BE 1500  
	 eth0   192.170.100.15  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:49:B8:BE 1500  
	 eth0   192.170.100.18  192.170.100.0   0.0.0.0         192.170.100.5   08:00:27:49:B8:BE 1500  
	 eth1   10.10.10.14     10.10.10.0      0.0.0.0         192.170.100.5   08:00:27:21:3F:94 9000  
	 eth1   169.254.101.122 169.254.0.0     0.0.0.0         192.170.100.5   08:00:27:21:3F:94 9000  

	Checking maximum (MTU) size packet goes through subnet...
	Check for maximum (MTU) size packet goes through subnet passed

	Check: Node connectivity of subnet "192.170.100.0"
	  Source                          Destination                     Connected?      
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01[192.170.100.12]     srvdonald01[192.170.100.17]     yes             
	  srvdonald01[192.170.100.12]     srvdonald01[192.170.100.16]     yes             
	  srvdonald01[192.170.100.12]     srvdonald01[192.170.100.13]     yes             
	  srvdonald01[192.170.100.12]     srvdonald02[192.170.100.14]     yes             
	  srvdonald01[192.170.100.12]     srvdonald02[192.170.100.15]     yes             
	  srvdonald01[192.170.100.12]     srvdonald02[192.170.100.18]     yes             
	  srvdonald01[192.170.100.17]     srvdonald01[192.170.100.16]     yes             
	  srvdonald01[192.170.100.17]     srvdonald01[192.170.100.13]     yes             
	  srvdonald01[192.170.100.17]     srvdonald02[192.170.100.14]     yes             
	  srvdonald01[192.170.100.17]     srvdonald02[192.170.100.15]     yes             
	  srvdonald01[192.170.100.17]     srvdonald02[192.170.100.18]     yes             
	  srvdonald01[192.170.100.16]     srvdonald01[192.170.100.13]     yes             
	  srvdonald01[192.170.100.16]     srvdonald02[192.170.100.14]     yes             
	  srvdonald01[192.170.100.16]     srvdonald02[192.170.100.15]     yes             
	  srvdonald01[192.170.100.16]     srvdonald02[192.170.100.18]     yes             
	  srvdonald01[192.170.100.13]     srvdonald02[192.170.100.14]     yes             
	  srvdonald01[192.170.100.13]     srvdonald02[192.170.100.15]     yes             
	  srvdonald01[192.170.100.13]     srvdonald02[192.170.100.18]     yes             
	  srvdonald02[192.170.100.14]     srvdonald02[192.170.100.15]     yes             
	  srvdonald02[192.170.100.14]     srvdonald02[192.170.100.18]     yes             
	  srvdonald02[192.170.100.15]     srvdonald02[192.170.100.18]     yes             
	Result: Node connectivity passed for subnet "192.170.100.0" with node(s) srvdonald01,srvdonald02


	Check: TCP connectivity of subnet "192.170.100.0"
	  Source                          Destination                     Connected?      
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01 : 192.170.100.12    srvdonald01 : 192.170.100.12    passed          
	  srvdonald01 : 192.170.100.17    srvdonald01 : 192.170.100.12    passed          
	  srvdonald01 : 192.170.100.16    srvdonald01 : 192.170.100.12    passed          
	  srvdonald01 : 192.170.100.13    srvdonald01 : 192.170.100.12    passed          
	  srvdonald02 : 192.170.100.14    srvdonald01 : 192.170.100.12    passed          
	  srvdonald02 : 192.170.100.15    srvdonald01 : 192.170.100.12    passed          
	  srvdonald02 : 192.170.100.18    srvdonald01 : 192.170.100.12    passed          
	  srvdonald01 : 192.170.100.12    srvdonald01 : 192.170.100.17    passed          
	  srvdonald01 : 192.170.100.17    srvdonald01 : 192.170.100.17    passed          
	  srvdonald01 : 192.170.100.16    srvdonald01 : 192.170.100.17    passed          
	  srvdonald01 : 192.170.100.13    srvdonald01 : 192.170.100.17    passed          
	  srvdonald02 : 192.170.100.14    srvdonald01 : 192.170.100.17    passed          
	  srvdonald02 : 192.170.100.15    srvdonald01 : 192.170.100.17    passed          
	  srvdonald02 : 192.170.100.18    srvdonald01 : 192.170.100.17    passed          
	  srvdonald01 : 192.170.100.12    srvdonald01 : 192.170.100.16    passed          
	  srvdonald01 : 192.170.100.17    srvdonald01 : 192.170.100.16    passed          
	  srvdonald01 : 192.170.100.16    srvdonald01 : 192.170.100.16    passed          
	  srvdonald01 : 192.170.100.13    srvdonald01 : 192.170.100.16    passed          
	  srvdonald02 : 192.170.100.14    srvdonald01 : 192.170.100.16    passed          
	  srvdonald02 : 192.170.100.15    srvdonald01 : 192.170.100.16    passed          
	  srvdonald02 : 192.170.100.18    srvdonald01 : 192.170.100.16    passed          
	  srvdonald01 : 192.170.100.12    srvdonald01 : 192.170.100.13    passed          
	  srvdonald01 : 192.170.100.17    srvdonald01 : 192.170.100.13    passed          
	  srvdonald01 : 192.170.100.16    srvdonald01 : 192.170.100.13    passed          
	  srvdonald01 : 192.170.100.13    srvdonald01 : 192.170.100.13    passed          
	  srvdonald02 : 192.170.100.14    srvdonald01 : 192.170.100.13    passed          
	  srvdonald02 : 192.170.100.15    srvdonald01 : 192.170.100.13    passed          
	  srvdonald02 : 192.170.100.18    srvdonald01 : 192.170.100.13    passed          
	  srvdonald01 : 192.170.100.12    srvdonald02 : 192.170.100.14    passed          
	  srvdonald01 : 192.170.100.17    srvdonald02 : 192.170.100.14    passed          
	  srvdonald01 : 192.170.100.16    srvdonald02 : 192.170.100.14    passed          
	  srvdonald01 : 192.170.100.13    srvdonald02 : 192.170.100.14    passed          
	  srvdonald02 : 192.170.100.14    srvdonald02 : 192.170.100.14    passed          
	  srvdonald02 : 192.170.100.15    srvdonald02 : 192.170.100.14    passed          
	  srvdonald02 : 192.170.100.18    srvdonald02 : 192.170.100.14    passed          
	  srvdonald01 : 192.170.100.12    srvdonald02 : 192.170.100.15    passed          
	  srvdonald01 : 192.170.100.17    srvdonald02 : 192.170.100.15    passed          
	  srvdonald01 : 192.170.100.16    srvdonald02 : 192.170.100.15    passed          
	  srvdonald01 : 192.170.100.13    srvdonald02 : 192.170.100.15    passed          
	  srvdonald02 : 192.170.100.14    srvdonald02 : 192.170.100.15    passed          
	  srvdonald02 : 192.170.100.15    srvdonald02 : 192.170.100.15    passed          
	  srvdonald02 : 192.170.100.18    srvdonald02 : 192.170.100.15    passed          
	  srvdonald01 : 192.170.100.12    srvdonald02 : 192.170.100.18    passed          
	  srvdonald01 : 192.170.100.17    srvdonald02 : 192.170.100.18    passed          
	  srvdonald01 : 192.170.100.16    srvdonald02 : 192.170.100.18    passed          
	  srvdonald01 : 192.170.100.13    srvdonald02 : 192.170.100.18    passed          
	  srvdonald02 : 192.170.100.14    srvdonald02 : 192.170.100.18    passed          
	  srvdonald02 : 192.170.100.15    srvdonald02 : 192.170.100.18    passed          
	  srvdonald02 : 192.170.100.18    srvdonald02 : 192.170.100.18    passed          
	Result: TCP connectivity check passed for subnet "192.170.100.0"


	Check: Node connectivity of subnet "10.10.10.0"
	  Source                          Destination                     Connected?      
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01[10.10.10.12]        srvdonald02[10.10.10.14]        yes             
	Result: Node connectivity passed for subnet "10.10.10.0" with node(s) srvdonald01,srvdonald02


	Check: TCP connectivity of subnet "10.10.10.0"
	  Source                          Destination                     Connected?      
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01 : 10.10.10.12       srvdonald01 : 10.10.10.12       passed
	  srvdonald02 : 10.10.10.14       srvdonald01 : 10.10.10.12       passed
	  srvdonald01 : 10.10.10.12       srvdonald02 : 10.10.10.14       passed
	  srvdonald02 : 10.10.10.14       srvdonald02 : 10.10.10.14       passed
	Result: TCP connectivity check passed for subnet "10.10.10.0"


	Check: Node connectivity of subnet "169.254.0.0"
	  Source                          Destination                     Connected?
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01[169.254.171.244]    srvdonald02[169.254.101.122]    yes
	Result: Node connectivity passed for subnet "169.254.0.0" with node(s) srvdonald01,srvdonald02


	Check: TCP connectivity of subnet "169.254.0.0"
	  Source                          Destination                     Connected?
	  ------------------------------  ------------------------------  ----------------
	  srvdonald01 : 169.254.171.244   srvdonald01 : 169.254.171.244   passed
	  srvdonald02 : 169.254.101.122   srvdonald01 : 169.254.171.244   passed
	  srvdonald01 : 169.254.171.244   srvdonald02 : 169.254.101.122   passed
	  srvdonald02 : 169.254.101.122   srvdonald02 : 169.254.101.122   passed
	Result: TCP connectivity check passed for subnet "169.254.0.0"


	Interfaces found on subnet "192.170.100.0" that are likely candidates for VIP are:
	srvdonald01 eth0:192.170.100.12 eth0:192.170.100.17 eth0:192.170.100.16 eth0:192.170.100.13
	srvdonald02 eth0:192.170.100.14 eth0:192.170.100.15 eth0:192.170.100.18

	Interfaces found on subnet "169.254.0.0" that are likely candidates for VIP are:
	srvdonald01 eth1:169.254.171.244
	srvdonald02 eth1:169.254.101.122

	Interfaces found on subnet "10.10.10.0" that are likely candidates for a private interconnect are:
	srvdonald01 eth1:10.10.10.12
	srvdonald02 eth1:10.10.10.14
	Checking subnet mask consistency...
	Subnet mask consistency check passed for subnet "192.170.100.0".
	Subnet mask consistency check passed for subnet "10.10.10.0".
	Subnet mask consistency check passed for subnet "169.254.0.0".
	Subnet mask consistency check passed.

	Result: Node connectivity check passed

	Checking multicast communication...

	Checking subnet "192.170.100.0" for multicast communication with multicast group "224.0.0.251"...
	Check of subnet "192.170.100.0" for multicast communication with multicast group "224.0.0.251" passed.

	Check of multicast communication passed.

	Verification of node connectivity was successful.
	```

* A creuser
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp ha -verbose

	Verifying Oracle Restart integrity

	ERROR:
	PRVG-5745 : CRS Configuration detected, Restart configuration check not valid in this environment
	Verification cannot proceed


	Verification of Oracle Restart integrity was unsuccessful.
	```

--------------------------------------------------------------------------------

* Verifying Permissions Required to Install Oracle Clusterware
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp admprv -n srvdonald01,srvdonald02 -o crs_inst -verbose

	Verifying administrative privileges 

	Checking user equivalence...

	Check: User equivalence for user "grid"
	  Node Name                             Status                  
	  ------------------------------------  ------------------------
	  srvdonald02                           passed                  
	  srvdonald01                           passed                  
	Result: User equivalence check passed for user "grid"

	Checking administrative privileges...

	Check: User existence for "grid" 
	  Node Name     Status                    Comment                 
	  ------------  ------------------------  ------------------------
	  srvdonald02   passed                    exists(1100)            
	  srvdonald01   passed                    exists(1100)

	Checking for multiple users with UID value 1100
	Result: Check for multiple users with UID value 1100 passed
	Result: User existence check passed for "grid"

	Check: Group existence for "oinstall"
	  Node Name     Status                    Comment
	  ------------  ------------------------  ------------------------
	  srvdonald02   passed                    exists
	  srvdonald01   passed                    exists
	Result: Group existence check passed for "oinstall"

	Check: Membership of user "grid" in group "oinstall" [as Primary]
	  Node Name         User Exists   Group Exists  User in Group  Primary       Status
	  ----------------  ------------  ------------  ------------  ------------  ------------
	  srvdonald02       yes           yes           yes           yes           passed
	  srvdonald01       yes           yes           yes           yes           passed
	Result: Membership check for user "grid" in group "oinstall" [as Primary] passed

	Check: Group existence for "asmdba"
	  Node Name     Status                    Comment
	  ------------  ------------------------  ------------------------
	  srvdonald02   passed                    exists
	  srvdonald01   passed                    exists
	Result: Group existence check passed for "asmdba"

	Check: Membership of user "grid" in group "asmdba"
	  Node Name         User Exists   Group Exists  User in Group  Status
	  ----------------  ------------  ------------  ------------  ----------------
	  srvdonald02       yes           yes           yes           passed
	  srvdonald01       yes           yes           yes           passed
	Result: Membership check for user "grid" in group "asmdba" passed

	Check: Group existence for "asmadmin"
	  Node Name     Status                    Comment
	  ------------  ------------------------  ------------------------
	  srvdonald02   passed                    exists
	  srvdonald01   passed                    exists
	Result: Group existence check passed for "asmadmin"

	Check: Membership of user "grid" in group "asmadmin"
	  Node Name         User Exists   Group Exists  User in Group  Status
	  ----------------  ------------  ------------  ------------  ----------------
	  srvdonald02       yes           yes           yes           passed
	  srvdonald01       yes           yes           yes           passed
	Result: Membership check for user "grid" in group "asmadmin" passed

	Administrative privileges check passed

	Verification of administrative privileges was successful.
	```

--------------------------------------------------------------------------------

* Vérification des prés requis :
	```
	cluvfy comp sys -n srvdonald01,srvdonald02 -p crs -verbose
	Verifying system requirement

	Check: Total memory
	  Node Name     Available                 Required                  Status
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald02   2.9396GB (3082344.0KB)    4GB (4194304.0KB)         failed
	  srvdonald01   2.9396GB (3082344.0KB)    4GB (4194304.0KB)         failed
	Result: Total memory check failed

	Check: Available memory
	  Node Name     Available                 Required                  Status
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald02   2.1177GB (2220588.0KB)    50MB (51200.0KB)          passed
	  srvdonald01   2.0831GB (2184280.0KB)    50MB (51200.0KB)          passed
	Result: Available memory check passed
	[...]
	Check: Package existence for "libaio(x86_64)" 
	  Node Name     Available                 Required                  Status    
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald02   libaio(x86_64)-0.3.109-13.el7  libaio(x86_64)-0.3.109    passed    
	  srvdonald01   libaio(x86_64)-0.3.109-13.el7  libaio(x86_64)-0.3.109    passed    
	Result: Package existence check passed for "libaio(x86_64)"

	Check: Package existence for "libaio-devel(x86_64)"
	  Node Name     Available                 Required                  Status
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald02   libaio-devel(x86_64)-0.3.109-13.el7  libaio-devel(x86_64)-0.3.109  passed
	  srvdonald01   libaio-devel(x86_64)-0.3.109-13.el7  libaio-devel(x86_64)-0.3.109  passed
	Result: Package existence check passed for "libaio-devel(x86_64)"

	Check: Package existence for "nfs-utils"
	  Node Name     Available                 Required                  Status
	  ------------  ------------------------  ------------------------  ----------
	  srvdonald02   nfs-utils-1.3.0-0.21.el7_2.1  nfs-utils-1.2.3-15        passed
	  srvdonald01   nfs-utils-1.3.0-0.21.el7_2.1  nfs-utils-1.2.3-15        passed
	Result: Package existence check passed for "nfs-utils"

	Checking for multiple users with UID value 0
	Result: Check for multiple users with UID value 0 passed

	Starting check for consistency of primary group of root user
	  Node Name                             Status
	  ------------------------------------  ------------------------
	  srvdonald02                           passed
	  srvdonald01                           passed

	Check for consistency of root user's primary group passed
	Check: Time zone consistency
	Result: Time zone consistency check passed

	Verification of system requirement was unsuccessful on all the specified nodes.
	```
	Voir au tout début, le 'unsuccessful' vient du fait que les nœuds n'ont que
	3Gb de RAM.

--------------------------------------------------------------------------------

* cluvfy comp ssa  -n all -verbose
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp ssa  -n all -verbose

	Verifying shared storage accessibility 

	Checking shared storage accessibility...

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  FRA                                   srvdonald01 srvdonald02 

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  DATA                                  srvdonald01 srvdonald02 

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  CRS                                   srvdonald01 srvdonald02 


	Shared storage check was successful on nodes "srvdonald01,srvdonald02"

	Verification of shared storage accessibility was successful.
	grid@srvdonald01:+ASM1:grid> cluvfy comp nodecon -n srvdonald01,srvdonald02

	Verifying node connectivity

	Checking node connectivity...

	Checking hosts config file...

	Verification of the hosts config file successful

	Checking maximum (MTU) size packet goes through subnet...
	Check for maximum (MTU) size packet goes through subnet passed
	Node connectivity passed for subnet "192.170.100.0" with node(s) srvdonald01,srvdonald02
	TCP connectivity check passed for subnet "192.170.100.0"

	Node connectivity passed for subnet "10.10.10.0" with node(s) srvdonald01,srvdonald02
	TCP connectivity check passed for subnet "10.10.10.0"

	Node connectivity passed for subnet "169.254.0.0" with node(s) srvdonald01,srvdonald02
	TCP connectivity check passed for subnet "169.254.0.0"


	Interfaces found on subnet "192.170.100.0" that are likely candidates for VIP are:
	srvdonald01 eth0:192.170.100.12 eth0:192.170.100.17 eth0:192.170.100.16 eth0:192.170.100.13
	srvdonald02 eth0:192.170.100.14 eth0:192.170.100.15 eth0:192.170.100.18

	Interfaces found on subnet "169.254.0.0" that are likely candidates for VIP are:
	srvdonald01 eth1:169.254.171.244
	srvdonald02 eth1:169.254.101.122

	Interfaces found on subnet "10.10.10.0" that are likely candidates for a private interconnect are:
	srvdonald01 eth1:10.10.10.12
	srvdonald02 eth1:10.10.10.14
	Checking subnet mask consistency...
	Subnet mask consistency check passed for subnet "192.170.100.0".
	Subnet mask consistency check passed for subnet "10.10.10.0".
	Subnet mask consistency check passed for subnet "169.254.0.0".
	Subnet mask consistency check passed.

	Node connectivity check passed

	Checking multicast communication...

	Checking subnet "192.170.100.0" for multicast communication with multicast group "224.0.0.251"...
	Check of subnet "192.170.100.0" for multicast communication with multicast group "224.0.0.251" passed.

	Check of multicast communication passed.

	Verification of node connectivity was successful.
	```

--------------------------------------------------------------------------------

* cluvfy comp ssa  -n all -verbose
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp ssa  -n all -verbose

	Verifying shared storage accessibility

	Checking shared storage accessibility...

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  FRA                                   srvdonald01 srvdonald02

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  DATA                                  srvdonald01 srvdonald02

	  ASM Disk Group                        Sharing Nodes (2 in count)
	  ------------------------------------  ------------------------
	  CRS                                   srvdonald01 srvdonald02


	Shared storage check was successful on nodes "srvdonald01,srvdonald02"

	Verification of shared storage accessibility was successful.
	```

--------------------------------------------------------------------------------

* cluvfy comp clu
	```
	grid@srvdonald01:+ASM1:grid> cluvfy comp clu

	Verifying cluster integrity

	Checking cluster integrity...


	Cluster integrity check passed


	Verification of cluster integrity was successful.
	```
