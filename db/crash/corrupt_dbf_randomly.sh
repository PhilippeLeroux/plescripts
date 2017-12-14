#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/usagelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg # Pour le mot de passe Oracle.
EXEC_CMD_ACTION=EXEC

typeset -r	ME=$0
typeset -r	PARAMS="$*"

typeset		pdb=undef
typeset		tbs=undef

# Number of blocks to corrupt.
typeset	-i	blocks=-1
# % of blocks to corrupt.
typeset	-i	pct=-1

# Near 50% of perf with 8 process and 2 CPU.
typeset	-i	max_dd_process=8

typeset		verbose=no

typeset		dbf=undef
typeset	-i	dbf_size_b=-1
typeset	-i	dbf_max_size_b=-1
typeset	-i	seek_blocks=0

# Default dd block size.
typeset	-ri	dd_block_size_b=512
# Default Oracle block size.
typeset	-ri	dbf_block_size_b=8192

add_usage "-pdb=pdb name"
add_usage "-tbs=tablespace name"			"Tablespace to corrupt."
add_usage "-max_size=#"						"Max size to corrupt, default dbf size. Defaut unit is byte."
add_usage "-blocks=#|-pct=%"				"Number or percent of blocks to corrupt."
add_usage "-max_threads=$max_dd_process"	"With 2 sockects $max_dd_process threads is better value with core i5."
add_usage "[-v]"							"Verbose mode."

typeset -r str_usage=\
"Usage :
$ME
$(print_usage)

Erase randomly $dd_block_size_b bytes from Oracle blocks of $(fmt_number $dbf_block_size_b) bytes.

Don't work with ASM.
"

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-pdb=*)
			pdb=$(to_upper ${1##*=})
			shift
			;;

		-tbs=*)
			tbs=$(to_upper ${1##*=})
			shift
			;;

		-max_threads=*)
			max_dd_process=${1##*=}
			shift
			;;

		-max_size=*)
			dbf_max_size_b=$(to_bytes ${1##*=})
			shift
			;;

		-blocks=*)
			blocks=${1##*=}
			shift
			;;

		-pct=*)
			pct=${1##*=}
			shift
			;;

		-v)
			verbose=yes
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

if command_exists crscrtl
then
	error "Don't work with ASM."
	LN
	info "$str_usage"
	LN
	exit 1
fi

exit_if_param_undef pdb		"$str_usage"
exit_if_param_undef tbs		"$str_usage"

ple_enable_log -params $PARAMS

exit_if_ORACLE_SID_not_defined

conn="sys/$oracle_password as sysdba"
query="\
select
	'space_header '||dbf_h.space_header
,   'dbf '||dbf_h.name
,   'dbf_bytes '||dbf_h.bytes
from
	v\$containers c
	inner join v\$datafile_header    dbf_h
		on c.con_id = dbf_h.con_id
where
	c.name = '$pdb'
and dbf_h.tablespace_name = '$tbs'
;"

while read var_name var_value
do
	[ x"$var_name" == x ] && continue || true

	case "$var_name" in
		space_header)
			seek_blocks=$(( var_value / dd_block_size_b ))
			;;

		dbf)
			dbf=$var_value
			;;

		dbf_bytes)
			dbf_size_b=$var_value
			;;

		*)
			error "Varibale $var_name unknow"
			LN
			exit 1
			;;
	esac
done<<<"$(sqlplus_exec_query_with "$conn" "$query")"

if [ $dbf_max_size_b -eq -1 ]
then # Guard
	dbf_max_size_b=$(( dbf_size_b - ( (dbf_size_b * 10) / 100 ) ))
fi

typeset	-ri	dbf_blocks=$(compute -i "$dbf_max_size_b / $dd_block_size_b")

if [[ $blocks -eq -1 && $pct -ne -1 ]]
then
	blocks=$(( ((dbf_blocks - seek_blocks)*$pct)/100 ))
fi

exit_if_param_undef blocks	"$str_usage"

exit_if_file_not_exists "$dbf"

info "PDB $pdb corrupt dbf :"
info "  $dbf"
info "  size        : $(fmt_bytes_2_better $dbf_size_b)"
info "  blocks      : $(fmt_number $dbf_blocks) of $dd_block_size_b bytes."
info "  seek blocks : $(fmt_number $seek_blocks) of $dd_block_size_b bytes. (dbf header space)"
info "  corrupt blocks before $(fmt_bytes_2_better $dbf_max_size_b)"
LN

info "  Oracle block size : $(fmt_number $dbf_block_size_b) bytes."
info "  dd block size     : $dd_block_size_b bytes."
info ""
info "  Max threads : $max_dd_process"
info "  $(fmt_number $blocks) blocks to corrupt."
if [ $blocks -gt $dbf_blocks ]
then
	blocks=$(( dbf_blocks - skip_blocks ))
	info "    correction #$blocks blocks to corrupt."
fi
typeset	-r	avg_sec_per_block="0.032"
typeset	-ri	estimate_secs=$(compute -i "$blocks * $avg_sec_per_block")
info "  Estimate time for blocks of 512 b between $(fmt_seconds $estimate_secs) and $(fmt_seconds $(( estimate_secs*2 )))"
LN

confirm_or_exit "Continue"
LN

typeset	-ri	start_at=$SECONDS
typeset	-i	total_seconds

# How many dd blocks in Oracle blocks :
# With default size dd block 512 b and Oracle block 8,192 b.
# 8,192 / 512 = 16 chunks.
# Only one chunk of 512 b is corrupted in Oracle block.
typeset	-ri	max_chunks=$(( dbf_block_size_b / dd_block_size_b ))

# FIFO array
typeset	-a	dd_pid_list

for (( iblock = 0; iblock < blocks; ++iblock ))
do
	# get a random block number.
	nr_block=$(shuf -i $seek_blocks-$dbf_blocks -n 1)

	# get the random chunk to corrupt in nr_block.
	block_chunk=$(( RANDOM % max_chunks ))

	# Offset in Oracle block
	dbf_block_offset=$((dd_block_size_b * block_chunk))

	if [ $verbose == yes ]
	then
		info "(#$block_chunk) Block $(fmt_number $nr_block) erase $dd_block_size_b bytes from offset $(fmt_number $dbf_block_offset )."
		LN
	fi

	dd conv=notrunc count=1 seek=$(( nr_block + dbf_block_offset )) if=/dev/zero of="$dbf" 1>/dev/null 2>&1 &
	if [ $? -ne 0 ]
	then
		error "dd failed."
		error "dd conv=notrunc count=1 seek=$(( nr_block + dbf_block_offset )) if=/dev/zero of=\"$dbf\" 1>/dev/null 2>&1"
		LN
		exit 1
	else
		dd_pid_list+=( $! )
		if [ ${#dd_pid_list[*]} -eq $max_dd_process ]
		then
			wait ${dd_pid_list[*]}
			dd_pid_list=()
		fi
	fi

	if [[ $iblock -ne 0 && $(( iblock % 10000 )) -eq 0 ]]
	then
		total_seconds=$(( SECONDS - start_at ))
		pct_blocks=$(( 100*(iblock+1)/blocks ))
		info "$(fmt_number $iblock) blocks corrupted (${pct_blocks}%) : $(fmt_seconds $total_seconds)"
	fi
done

[ ${#dd_pid_list[*]} -ne 0 ] && wait ${dd_pid_list[*]} || true

total_seconds=$(( SECONDS - start_at ))
info "$(fmt_number $iblock) blocks corrupted : $(fmt_seconds $total_seconds) "
info "$(fmt_bytes_2_better $(( iblock * dd_block_size_b )) ) corrupted."
LN
