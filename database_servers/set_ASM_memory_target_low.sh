#!/bin/bash

sqlplus -s / as sysasm<<EOS
alter system set "_asm_allow_small_memory_target"=true scope=spfile;
alter system set memory_target=750m scope=spfile;
alter system set memory_max_target=750m scope=spfile;
exit
EOS

