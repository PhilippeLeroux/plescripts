#!/bin/bash

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg

function sqlcmd_set_low_memory
{
	set_sql_cmd "alter system set \"_asm_allow_small_memory_target\"=true scope=spfile sid='*';"
	set_sql_cmd "alter system set memory_max_target=$hack_asm_memory scope=spfile sid='*';"
}

sqlplus_asm_cmd "$(sqlcmd_set_low_memory)"
LN
