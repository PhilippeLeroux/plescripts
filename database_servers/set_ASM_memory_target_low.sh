#!/bin/bash

. ~/plescripts/global.cfg

sqlplus -s / as sysasm<<EOS
alter system set "_asm_allow_small_memory_target"=true scope=spfile sid='*';
alter system set memory_max_target=$hack_asm_memory scope=spfile sid='*';
exit
EOS
