# vim: ts=4:sw=4

[ ! -z $plelib_banner ] && return 0

LANG=C
umask 0002

################################################################################
#	Initialisation de la lib.
################################################################################

typeset -ri	plelib_release=3
typeset -r	plelib_banner=$(printf "plelib V%02d" $plelib_release)

#*< Active les effets visuels couleurs et autres.
function enable_markers
{
	## Reset to normal:
	NORM="\e[0m"

	## Colors:
	BLACK="\e[0;30m"
	GRAY="\e[1;30m"
	RED="\e[0;31m"
	LRED="\e[1;31m"
	GREEN="\e[0;32m"
	LGREEN="\e[1;32m"
	YELLOW="\e[0;33m"
	LYELLOW="\e[1;33m"
	BLUE="\e[0;34m"
	LBLUE="\e[1;34m"
	PURPLE="\e[0;35m"
	PINK="\e[1;35m"
	CYAN="\e[0;36m"
	LCYAN="\e[1;36m"
	LGRAY="\e[0;37m"
	WHITE="\e[1;37m"

	## Backgrounds
	BLACKB="\e[0;40m"
	REDB="\e[0;41m"
	GREENB="\e[0;42m"
	YELLOWB="\e[0;43m"
	BLUEB="\e[0;44m"
	PURPLEB="\e[0;45m"
	CYANB="\e[0;46m"
	GREYB="\e[0;47m"

	## Attributes:
	UNDERLINE="\e[4m"
	BOLD="\e[1m"
	INVERT="\e[7m"
	BLINK="\e[5m"
	ITALIC="\e[3m"			# Ne fonctionne qu'avec xterm
	STRIKE="\e[9m"			# Ne fonctionne qu'avec xterm

	#	Clear End Of Line
	CEOL="\e[K"
}

#*< Désactive les effets visuels couleurs et autres.
function disable_markers
{
	## Reset to normal:
	NORM=

	## Colors:
	BLACK=
	GRAY=
	RED=
	LRED=
	GREEN=
	LGREEN=
	YELLOW=
	LYELLOW=
	BLUE=
	LBLUE=
	PURPLE=
	PINK=
	CYAN=
	LCYAN=
	LGRAY=
	WHITE=

	## Backgrounds
	BLACKB=
	REDB=
	GREENB=
	YELLOWB=
	BLUEB=
	PURPLEB=
	CYANB=
	GREYB=

	## Attributes:
	UNDERLINE=
	BOLD=
	INVERT=
	BLINK=
	ITALIC=
	STRIKE=
}

#	============================================================================
#	Valeurs de PLELIB_OUTPUT
#		- ENABLE	: Effets d'affichage
#		- DISABLE	: Aucun effets d'affichage
#		- FILE		: Effet d'affichage et écriture dans la log définie par PLELIB_LOG_FILE
#
#	Si PLELIB_LOG_FILE est définie alors PLE_OUTPUT sera positionné à FILE
[ x"$PLELIB_OUTPUT" = x ] && PLELIB_OUTPUT=ENABLE

typeset -r PLELOG_ROOT=~/plescripts/logs
if [ ! -d $PLELOG_ROOT ]
then
	mkdir $PLELOG_ROOT >/dev/null 2>&1
	chmod ug=rwx,o=rx $PLELOG_ROOT >/dev/null 2>&1
fi

typeset -r PLELOG_PATH=$PLELOG_ROOT/$(date +"%Y-%m-%d")

if [ "$PLELIB_OUTPUT" = "FILE" ] && [ x"$PLELIB_LOG_FILE" = x ]
then
	PLELIB_LOG_FILE=${0##*/}
	PLELIB_LOG_FILE=$PLELOG_PATH/$(date +"%Hh%Mmn%S")_$(hostname -s)_${PLELIB_LOG_FILE%.*}.log
fi

[ x"$PLELIB_LOG_FILE" != x ] && PLELIB_OUTPUT=FILE

[ "$PLELIB_OUTPUT" = DISABLE ] && disable_markers || enable_markers

typeset -r OK="${GREEN}ok${NORM}"
typeset -r KO="${RED}ko${NORM}"

#	Le répertoire doit être créée !
if [ ! -d $PLELOG_PATH ]
then
	echo "mkdir $PLELOG_PATH"
	mkdir $PLELOG_PATH
	chown kangs:users $PLELOG_PATH
	chmod ug=rwx,o=rx $PLELOG_PATH
	[ $? -ne 0 ] && exit 1
fi

if [ ! -f $PLELIB_LOG_FILE ]
then	# Obligatoire lors de l'utilisation répertoire partagé vboxf
		# Avec NFS pas de problème (plus utilisé pour lenteur excessive)
	touch $PLELIB_LOG_FILE >/dev/null 2>&1
	chmod ug=rw,o=r $PLELIB_LOG_FILE
	[ $? -ne 0 ] && exit 1
fi

#	============================================================================

if [ ! -z PLE_SHOW_EXECUTION_TIME_AFTER ]
then	# Temps en secondes, le temps d'exécution des commandes est affiché
		# s'il est supérieur à cette variable
	typeset -i PLE_SHOW_EXECUTION_TIME_AFTER=60
fi

################################################################################
#	Fonctions supprimant les effets visuelles des logs.
################################################################################

#*> Remove all visual makers from file $1
function clean_log_file
{
	if [ -f "$1" ]
	then
		sed -i -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" "$1"
		sed -i -r "s/\x1B\[[0-9]m//g" "$1"
		sed -i "s/\r//g" "$1"
	fi
}

#*< Remove all visual makers for log file generate by plelib
function clean_plelib_log_file
{
	# Le premier appel permet de flusher la log.
	clean_log_file "$PLELIB_LOG_FILE"
	# La log est 'flushée' permet de traiter la fin de la log.
	# Marche pas toujours, mais je laisse.
	clean_log_file "$PLELIB_LOG_FILE"
}

[ x"$PLELIB_LOG_FILE" != x ] && trap clean_plelib_log_file EXIT

[ x"$EXEC_CMD_ACTION" = x ] && typeset EXEC_CMD_ACTION=NOP

################################################################################
#	Fonctions agissants ou donnant des informations sur le terminal.
################################################################################

#*> Hide cursor
function hide_cursor
{
	tput civis
}

#*> Show cursor
function show_cursor
{
	tput cnorm
}

#*> return number of col for the terminal
function term_cols
{
	tput cols
}

#*< Show cursor on Ctrl+c
function ctrl_c
{
	show_cursor
	exit 1
}

trap ctrl_c INT

################################################################################
#	Fonctions d'affichages
################################################################################

#*< Used by fonctions info, warning and error.
#*< Action depand of PLELIB_OUTPUT
#*<		DISABLE : no visual effects.
#*<		ENABLE	: visual effects
#*<		FILE	: write into $PLELIB_LOG_FILE without any effects and canal 1 with visual effects.
function my_echo
{
	EOL="\n"
	[ "$1" = "-n" ] && EOL="" && shift
	typeset -r	color="$1"
	typeset		symbol="$2"
	[ "$symbol" = no_symbol ] && symbol=""
	shift 2

	# Laisser les 2 lignes, sinon l'affichaged de MSG est foireux.
	MSG="$@"
	MSG=$(double_symbol_percent "$MSG")

	# Escape tous les \1, \2 jusque \9
	MSG=$(sed 's!\\\([1-9]\)!\\\\\1!g' <<< "$MSG")

	case "$PLELIB_OUTPUT" in
		"DISABLE")
			printf "${symbol}${MSG}$EOL"
			;;

		"ENABLE")
			printf "${color}${symbol}${NORM}${MSG}$EOL"
			;;

		"FILE")
			printf "${color}${symbol}${NORM}${MSG}$EOL"
			printf "${symbol}${MSG}$EOL" >> $PLELIB_LOG_FILE
			;;

		*)
			echo "PLELIB_OUTPUT='$PLELIB_OUTPUT' invalid.">&2
			exit 1
			;;
	esac
}

#*> Print error message
function error
{
	my_echo "${RED}${BLINK}" "*" " $@"
}

#*> Print warning message
function warning
{
	my_echo "${LGREEN}${INVERT}" "<" " $@"
}

#*< Write mark info
#*< Usage :
#*< mark_info; printf "Hellow %s\n" name
#*< N'est plus utilisée : la supprimée.
function mark_info
{
	my_echo -n "${PURPLE}" "# "
}

#*> Affiche les informations de debug.
#*> Actif uniquement si la variable DEBUG_FUNC=enable est définie.
#*> Fonction sur le même principe que info.
function debug
{
	[ "$DEBUG_FUNC" != enable ] && return 0

	first_arg=""
	symbol="dbg"
	while [ $# -ne 0 ]
	do
		case "$1" in
			"-n")
				[ x"$first_arg" == x ] && first_arg="-n" || first_arg="$first_arg -n"
				shift
				;;

			"-f")
				symbol="no_symbol"
				shift
				;;

			*)
				break;
		esac
	done

	my_echo $first_arg "${BLUE}" "$symbol" " $@"
}

#*>	Print normal message
#*> Options
#*>   -n no new line
#*>   -f don't print info marker. (Useful after info -n)
function info
{
	first_arg=""
	symbol="# "
	while [ $# -ne 0 ]
	do
		case "$1" in
			"-n")
				[ x"$first_arg" == x ] && first_arg="-n" || first_arg="$first_arg -n"
				shift
				;;

			"-f")
				symbol="no_symbol"
				shift
				;;

			*)
				break;
		esac
	done

	my_echo $first_arg "${PURPLE}" "$symbol" "$@"
}

#*> line_separator [car]
#*> Fill line with charactere = or specified charactere
function line_separator
{
	[ $# -eq 0 ] && car="=" || car="$1"

	info $(fill "$car" $(tput cols)-3)
}

#*> New line
function LN
{
	my_echo "${NORM}" ""
}

#*> -reply_list=str	liste des réponses séparées par un espace, par défaut "y n"
#*> Pour CR passer CR puis -print=""
#*> -print=str		les réponses à afficher, par défaut "y/n ?"
#*> Les autres paramètres sont la questions.
#*>	return :
#*>		0	for first answer.
#*>		1	for second answer.
#*>		3	for third answer.
#*> Example :
function ask_for
{
	typeset reply_list="y n"
	typeset print="y/n ?"
	while [ 0 -eq 0 ]	# forever
	do
		case $1 in
			-fr)
				typeset reply_list="o n"
				typeset print="o/n ?"
				shift
				;;

			-reply_list=*)
				reply_list="${1##*=}"
				shift
				;;

			-print=*)
				print="${1##*=}"
				shift
				;;

			*)
				break;
		esac
	done

	typeset yes_reply
	typeset no_reply
	typeset third_reply
	read yes_reply no_reply third_reply <<<"$reply_list"

	[ "$yes_reply" == CR ] && print=""

	typeset keyboard=nothing

	while [ 0 -eq 0 ]	# forever
	do
		[ x"$print" == x ] && info -n "$@" || info -n "$@ $print "

		#	Wait user.
		typeset -i start_s=$SECONDS
		read keyboard</dev/tty
		typeset -i diff_s=$(( SECONDS - start_s ))
		[ $diff_s -gt 60 ] && info "Idle time $(fmt_seconds $diff_s)"

		case "$keyboard" in
			'')
				[ "$yes_reply" == "CR" ] && return 0 || return 1
				;;

			"$yes_reply")
				return 0
				;;

			"$no_reply")
				return 1
				;;

			"$third_reply")
				return 3
				;;

			*)
				error "'$keyboard' invalid."
				;;
		esac
	done
	info "Pas normal !"
}

#*> Pour les paramètres voir ask_for
#*> Si l'utilisateur répond non le script est terminé par un exit 1
function confirm_or_exit
{
	ask_for "$@"
	[ $? -eq 1 ] && exit 1 || return 0
}

################################################################################
#	Fonctions permettant d'exécuter des commandes ou scripts.
################################################################################

#*> Fake exec_cmd command
#*> Command printed but not executed.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function fake_exec_cmd
{
	case $EXEC_CMD_ACTION in
		NOP)
			my_echo "${YELLOW}" "${INVERT}nop  >${NORM} " "$@"
			return 1
			;;

		EXEC)
			my_echo "${YELLOW}" "${INVERT}$(date +"%Hh%M")>${NORM} " "$@"
			return 0
	esac
}

#*< Extrait la commande de "$@"
#*< Si la première commande est ssh alors recherche la commande exécutée par ssh
function get_cmd_name
{
	read -a argv <<<"$@"

	typeset -ri size=${#argv[@]}

	case "${argv[0]}" in
		sudo)
			echo "${argv[1]} (${argv[0]})"
			return 0
			;;
	esac

	# TODO prendre charge su :
	#		Formats root
	#		su - root -c cmd
	#		su - -c cmd
	#		su root -c cmd
	#		Formats utilisateur
	#		su - username -c cmd
	#		su username -c cmd

	if [ "${argv[0]}" != ssh ] || [ $size -eq 1 ]
	then	# Ce n'est pas ssh ou il n'y a qu'une seule commande
		echo ${argv[0]}
		return 0
	fi

	# Passe tous les arguments de ssh
	typeset -i argc=1
	while [ $argc -ne $size ]
	do
		arg=${argv[$argc]}
		[ ${arg:0:1} != - ] && break

		argc=argc+1
	done

	# Ici argc pointe sur la chaîne de connexion.
	# La commande est donc sur argc+1
	if [ $(( argc + 1 )) -eq $size ]
	then # Pas de commande c'est un ssh interactif
		echo "ssh (interactif)"
		return 0
	fi

	typeset cmd=${argv[argc+1]}

	# Si la commande débute par une double quote (") elle est supprimée.
	[ "${cmd:0:1}" = \" ] && cmd=${cmd:1} || true
	# Si la commande termine par une double quote (") elle est supprimée.
	[ "${cmd:${#cmd}-1:1}" = \" ] && cmd=${cmd:0:${#cmd}-1} || true

	#	TODO : ne plus mémoriser la commande mais la position !

	[ "$cmd" == "sudo" ] && cmd=${argv[argc+2]}

	# Si la commande est LANG=C on passe à la suivante.
	[ "$cmd" == "LANG=C" ] && cmd=${argv[argc+2]}

	# Si la commande est '.' c'est qu'un fichier profile est chargé on passe le
	# profile : . ./.profile ... donc pointe sur 3
	[ "$cmd" == "." ] && cmd=${argv[argc+3]}
	# Arrive dans ce scénario : . ./.profile \; ....
	[ "$cmd" == ";" ] && cmd=${argv[argc+4]}

	echo "$cmd (ssh)"
}

#*> exec_cmd
#*> if EXEC_CMD_ACTION
#*>    == NOP  : command is printed (No Operation)
#*>    == EXEC : command is printed & executed
#*>
#*> If command failed stop the scripts.
#*>
#*> Parameters:
#*>		-f  EXEC_CMD_ACTION is ignored.
#*>		-c  continue on error.
#*>		-ci like -c but not print error message.
#*>		-h  hide command except on error.
#*>		-hf hide command even on error.
#*>
#*> Show execution time after PLE_SHOW_EXECUTION_TIME_AFTER seconds
function exec_cmd
{
	# Mémo : ne jamais utiliser $1 $2 ... mais uniquement $*
	#	exec_cmd ls -rtl	est valable
	#	exec_cmd "ls -rtl"	l'est aussi.
	typeset force=NO
	typeset continue_on_error=NO
	typeset hide_command=NO

	while [ 0 -eq 0 ]	# forever
	do
		case "$1" in
			"-f")
				shift
				if [ $EXEC_CMD_ACTION = NOP ]
				then
					EXEC_CMD_ACTION=EXEC
					force=YES
				fi
				;;

			"-cont"|"-c")	# Affiche un message si la commande échoue
				shift
				continue_on_error=YES
				;;

			"-ci")			# N'affiche pas de message si la commande échoue
				shift
				continue_on_error=YES_AND_HIDE_MESSAGE
				;;

			"-h")
				shift
				hide_command=YES
				;;

			"-hf")
				shift
				hide_command=YES_EVEN_ON_ERROR
				;;

			*)
				break
				;;
		esac
	done

	typeset -i	eval_return

	typeset	-r	simplify_cmd=$(echo "$*" | tr -s '\t' ' ' | tr -s [:space:])

	case $EXEC_CMD_ACTION in
		NOP)
			my_echo "${YELLOW}" "nop > " "$simplify_cmd"
			;;

		EXEC)
			[ $force == YES ] && COL=$RED || COL=$YELLOW
			[ $hide_command == NO ] && my_echo "$COL" "$(date +"%Hh%M")> " "$simplify_cmd"

			typeset -ri eval_start_at=$SECONDS
			if [ x"$PLELIB_LOG_FILE" == x ]
			then
				eval "$*"
				eval_return=$?
			else
				eval "$*" 2>&1 | tee -a $PLELIB_LOG_FILE
				eval_return=${PIPESTATUS[0]}

				#	BUG workaround :
				[ x"$eval_return" == x ] &&	eval_return=0
			fi

			if [ $hide_command == NO ]
			then
				typeset -ri eval_duration=$(( SECONDS - eval_start_at ))
				if [ $eval_duration -gt $PLE_SHOW_EXECUTION_TIME_AFTER ]
				then
					my_echo "${YELLOW}" "$(date +"%Hh%M")< " "$(get_cmd_name "$@") running time : $(fmt_seconds $eval_duration)"
				fi
			fi

			if [ $eval_return -ne 0 ]
			then
				[ $hide_command == YES ] && my_echo "$COL" "$(date +"%Hh%M")> " "$@"

				typeset -r user_cmd=$(cut -d' ' -f1 <<< "$@")
				if [ $continue_on_error == NO ]
				then
					error "$user_cmd return $eval_return"
				else
					[ $continue_on_error == YES ] && warning "$user_cmd return $eval_return"
				fi

				[ $force == YES ] && EXEC_CMD_ACTION=NOP

				[ $continue_on_error == NO ] && exit 1
			fi
			;;

		*)
			error "Bad value for EXEC_CMD_ACTION = '$EXEC_CMD_ACTION'"
			exit 1
			;;
	esac

	[ $force == YES ] && EXEC_CMD_ACTION=NOP

	return $eval_return
}

typeset -a	ple_fake_param_cmd
typeset -i	ple_param_max_len=0

#*> $1 parameter to add.
function add_dynamic_cmd_param
{
	typeset -r	param="$1"
	typeset -ri	len=${#param}
	ple_fake_param_cmd[${#ple_fake_param_cmd[@]}]="$param"

	if [[ $len -gt $ple_param_max_len && $len -lt $(term_cols) ]]
	then
		ple_param_max_len=${#param}
	fi
}

#*> run command '$@' with parameters define with add_dynamic_cmd_param
#*> if first parameter is -confirm a prompt is printed to confirm or not execution.
#*> For other parameters see exec_cmd
function exec_dynamic_cmd
{
	typeset confirm=no
	while [ 0 -eq 0 ]
	do
		case "$1" in
			"-confirm")
				confirm=yes
				shift
				;;

			*)
				break;
				;;
		esac
	done

	typeset -r cmd_name="$@"

	ple_param_max_len=ple_param_max_len+2

	#	4 correspond à la largeur de la tabulation ajoutée devant les paramètres,
	#	le but étant d'aligner le \ derrière la commande aux \ derrière les paramètres.
	#	Ex :
	#	10h40> ma_commande  \
	#              -x=42    \
	#			   -t
	typeset -ri l=ple_param_max_len+4
	typeset		c=$(printf "%-${l}s" "${cmd_name##* }")
	fake_exec_cmd "$(echo "$c\\\\")"

	#	Affiche les paramètres de la commande :
	for i in $( seq ${#ple_fake_param_cmd[@]} )
	do
		[ $i -gt 1 ] && echo "\\"
		#	La largeur de l'horodatage 'HHhMM >' est de 7, la tabulation devant les
		#	paramètres est de 4, donc insertion d'une tabulation de 11.
		printf "%11s%-${ple_param_max_len}s" " " "${ple_fake_param_cmd[$i-1]}"
	done
	LN

	[ $confirm == yes ] && confirm_or_exit "Continue" || true

	#	Avec la paramètre -h exec_cmd n'affiche pas le temps d'exécution.
	typeset -ri	exec_cmd_start_at=$SECONDS
	exec_cmd -hf $cmd_name "${ple_fake_param_cmd[@]}"
	typeset -ri exec_cmd_return=$?

	typeset -ri exec_cmd_duration=$(( $SECONDS - $exec_cmd_start_at ))
	if [ $exec_cmd_duration -gt $PLE_SHOW_EXECUTION_TIME_AFTER ]
	then
		my_echo "${YELLOW}" "$(date +"%Hh%M")< " "${cmd_name##* } running time : $(fmt_seconds $exec_cmd_duration)"
	fi

	unset ple_fake_param_cmd
	ple_param_max_len=0

	return $exec_cmd_return
}

################################################################################
#	Fonctions agissant sur les fichiers ou répertoires.
################################################################################

#*> exit_if_file_not_exists <name> [message]
#*> if file <name> not exists, script aborted.
#*> Print [message] if specified.
function exit_if_file_not_exists
{
	if [ ! -f "$1" ]
	then
		error "File '$1' not exists."
		shift
		while [ $# -ne 0 ]
		do
			error "$1"
			shift
		done
		exit 1
	fi
}

#*> exit_if_dir_not_exists <name> [message]
#*> if directory <name> not exits, script aborted.
#*> Print [message] if specified.
function exit_if_dir_not_exists
{
	if [ ! -d $1 ]
	then
		error "Directory '$1' not exists."
		shift
		while [ $# -ne 0 ]
		do
			error "$1"
			shift
		done
		exit 1
	fi
}

################################################################################
#	Fonctions agissant sur le contenu d'un fichier.
################################################################################

#*<	Test if a variable exists, format ^var\\s*=\\s*value
#*<	1	variable name
#*<	2	file name
function exist_var
{
	grep -E "^${1}\s*=\s*" "$2" >/dev/null 2>&1
}

#*< change_value <var> <value> <file>
#*<	Format ^var\\s*=\\s*value
function change_value
{
	typeset -r var_name=$(escape_slash "$1")
	typeset -r file=$3
	[ "$2" = "empty" ] && new_val="" || new_val=$(escape_slash "$2")

	exec_cmd "sed -i 's/^\(${var_name}\s*=\s*\).*/\1$new_val/' $file"
}

#*< add_value <var> <value> <file>
#*< Format : var=value
#*< If <value> == empty no value specified.
function add_value
{
	typeset -r var_name="$1"
	[ "$2" = "empty" ] && new_val="" || new_val="$2"
	typeset -r file="$3"

	exec_cmd "echo \"$var_name=$new_val\" >> $file"
}

#*> update_value <var> <value> <file>
#*>	Update variable <var> from file <file> with value <value>
#*> If variable doesn't exist, it's added.
#*> If value = empty reset value but not remove variable.
#*>
#*<	Format ^var\\s*=\\s*value
#*>
#*> If file doesn't exist script aborted.
function update_value
{
	[ $EXEC_CMD_ACTION = EXEC ] && exit_if_file_not_exists "$3" "Call function update_value"

	typeset -r var_name="$1"
	typeset -r var_value="$2"
	typeset -r file="$3"

	exist_var "$var_name" "$file"
	if [ $? -eq 0 ]
	then
		change_value "$var_name" "$var_value" "$file"
	else
		add_value "$var_name" "$var_value" "$file"
	fi
}

#*> remove_value <var> <file>
#*>
#*> Remove variable <var> from file <file>
#*>		Format ^war\s*=.*
#*>
#*> If file doesn't exist script aborted.
function remove_value
{
	[ $EXEC_CMD_ACTION = EXEC ] && exit_if_file_not_exists "$2" "Call function remove_value"

	typeset -r var_name=$(escape_slash "$1")
	typeset -r file="$2"
	exist_var "$var_name" "$file"
	if [ $? -eq 0 ]
	then
		exec_cmd "sed -i '/^${var_name}\s*=.*$/d' $file"
	else
		info "remove_value : variable '$var_name' not exists in $file"
	fi
}

################################################################################
#	Fonctions permettant de tester les arguments des scripts.
################################################################################

#*> exit_if_param_undef <var> [message]
#*>
#*> Script aborted if var == undef or == -1 or empty
function exit_if_param_undef #var_name
{
	typeset -r var_name=$1
	typeset -r var_value=$(eval echo \$$var_name)

	if [ "$var_value" = "undef" ] || [ "$var_value" = "-1" ] || [ x$"var_name" == x ]
	then
		error "-$var_name missing"
		shift
		[ $# -ne 0 ] && LN && info "$@"
		LN
		exit 1
	fi
}

#*> exit_if_param_invalid var_name val_list [message]
#*>
#*> Script aborted if var
#*>		= undef or -1
#*>		not in the list val_list
function exit_if_param_invalid
{
	typeset -r var_name=$1
	typeset -r val_list=$2
	shift 2

	typeset -r var_value=$(eval echo \$$var_name)

	exit_if_param_undef $var_name "$@"

	grep -E "\<${var_value}\>" <<< "$val_list" >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		error "-$var_name=$var_value invalid."
		[ $# -ne 0 ] && LN && info "$@"
		LN
		exit 1
	fi
}

################################################################################
#	Fonctions transformants des chaînes de caractères.
################################################################################

#*> Double symbol % from $@.
function double_symbol_percent
{
	sed "s/%/%%/g" <<< "$@"
}

#*> Escape " from $@
function escape_2xquotes
{
	sed 's/"/\\\"/g' <<< "$@"
}

#*> Escape / from $@
function escape_slash
{
	sed "s/\//\\\\\//g" <<< "$@"
}

#*> Escape \ from $@
function escape_anti_slash
{
	sed 's/\\/\\\\/g' <<<"$@"
}

#*> Upper case "$@"
function to_upper
{
	tr [:lower:] [:upper:] <<< "$@"
}

#*> Lower case "$@"
function to_lower
{
	tr [:upper:] [:lower:] <<< "$@"
}

#*> Upper case the first caractere of $1
function initcap
{
	sed 's/\(.\)/\U\1/' <<< "$@"
}

#*> A supprimer ?
#*>	$1 max len
#*>	$2 string
#*>
#*>	Si la longueur de string est supérieur à max len alors
#*>	string est raccourcie pour ne faire que max len caractères.
#*>
#*>	Par exemple
#*>				XXXXXXXXXXXXXXXXXXX
#*>	deviendra	XXX...XXX
function shorten_string
{
	typeset -i	max_len=$1
	typeset -r	string=$2
	typeset -ri	string_len=${#string}

	if [ $string_len -gt $max_len ]
	then
		max_len=max_len-3 #-3 pour les ...
		typeset -ri	car_to_remove=$(compute -i "($string_len - $max_len)/2")
		typeset -ri begin_len=$(compute -i "$string_len / 2 - $car_to_remove")
		typeset -ri end_start=$(compute -i "$string_len - ( $string_len / 2 - $car_to_remove )" )
		comp="${string:0:$begin_len}...${string:$end_start}"
		echo "$comp"
	else
		echo $string
	fi
}

#*> A supprimer ?
#*> $1 gap		(si non précisé vaudra 0)
#*> $2 string
function string_fit_on_screen
{
	typeset -i	gap=1
	typeset 	string="$1"
	if [ $# -eq 2 ]
	then
		gap=$1
		string="$2"
	fi

	typeset -i len=$(term_cols)
	len=len-gap

	shorten_string $len "$string"
}

#*> return string :
#*>	  true	if $1 in( y, yes )
#*>   false if $1 in( n, no )
function yn_to_bool
{
	case $1 in
		y|yes)	echo true
				;;

		n|no)	echo false
				;;
	esac
}

#*> fill <car> <no#>
#*> Return a buffer filled with no# characteres car
function fill
{
	typeset -r	car="$1"
	typeset -ri	nb=$2

	typeset buffer
	typeset -i count=0
	while [ $count -lt $nb ]
	do
		buffer=$buffer$car
		count=count+1
	done

	echo $buffer
}

################################################################################
#	Fonctions pratiques sur le temps.
################################################################################

#*> pause_in_secs <seconds>
#*> Fait une pause de <seconds> secondes.
#*> Le décompte du temps écoulé sera affiché à la position courante du curseur.
#*> Retourne la longueur utilisée pour afficher le décompte ce qui permet
#*> d'effacer l'affichage.
function pause_in_secs
{
	typeset -ri	max_secs=$1
	[ $# -eq 2 ] && suffix="$2"

	typeset -i	secs=0
	typeset		backspaces
	typeset		buffer=""

	case "$PLELIB_OUTPUT" in
		"ENABLE"|"FILE")
			hide_cursor

			while [ $secs -ne $max_secs ]
			do
				buffer=$(printf "${secs}s/${max_secs}s")
				[ $# -eq 2 ] && buffer="$buffer$suffix"

				printf "$backspaces$buffer$CEOL"
				sleep 1
				secs=secs+1
				backspaces=$(fill "\b" $((${#buffer})))
			done

			buffer=$(printf "${max_secs}/${max_secs}s")
			printf "${backspaces}$buffer$CEOL"

			show_cursor

			[ "$PLELIB_OUTPUT" = "FILE" ] && printf "${max_secs}/${max_secs}s" >> $PLELIB_LOG_FILE
		;;

		"DISABLE")
			printf "${max_secs}s> "
			while [ $secs -ne $max_secs ]
			do
				printf "."
				sleep 1
				secs=secs+1
			done

			buffer="${max_secs}s>: "$(fill . $max_secs)
			if [ $# -eq 2 ]
			then
				printf " $suffix"
				buffer=$buffer" "$suffix
			fi
		;;
	esac

	return ${#buffer}
}

#*> chrono_start
#*> Démarre le chrono
function chrono_start
{
	ple_start=$SECONDS
}

#*> chrono_stop [message]
#*> Affiche le temps écoulé depuis le dernier appel à chrono_start
#*> Si le premier paramètre est -q alors retourne le temps écoulé.
function chrono_stop
{
	if [ $# -eq 0 ]
	then
		info "$(fmt_seconds $(( SECONDS - ple_start )) )"
	else
		if [ "$1" = "-q" ]
		then
			echo $(( SECONDS - ple_start ))
		else
			info "$1 ${BOLD}$(fmt_seconds $(( SECONDS - ple_start )) )${NORM}"
		fi
	fi
}

PAUSE=OFF
function test_pause # $1 message
{
	if [ $PAUSE == ON ]
	then
		[ $# -ne 0 ] && info "$@"
		info "Press a key to continue" && read keyboard
	fi
}

################################################################################
#	Fonctions de formatage et de manipulation de nombres.
################################################################################

#*> Eval an arithmetic expression
#*> Flags
#*>    -l[#] : use real numbers with # number decimals
#*>    -i : remove all decimals
function compute
{
	bc_args=""
	scale=""
	return_int=no

	while [ $# -ne 0 ]
	do
		case "$1" in
			-l*)
				bc_args="-l"
				[ ${#1} -gt 2 ] && scale="${1:2}"
				shift
				;;

			-i)
				return_int=yes
				shift
				;;
			*)
				break
		esac
	done

	val=$(echo "$@" | bc $bc_args)
	[ x"$scale" != x ] && val=$(LANG=C printf "%.${scale}f" $val)
	[ $return_int = yes ] && echo ${val%%.*} || echo $val
}

#*> fmt_seconds <seconds>
#*> <seconds> formate to the better format
function fmt_seconds # $1 seconds
{
	typeset -ri seconds=$1

	typeset -i minutes=$seconds/60

	if [ $minutes -eq 0 ]
	then
		printf "%ds\n" $seconds
	elif [ $minutes -lt 60 ]
	then
		typeset -i modulo=$(( seconds % 60 ))
		printf "%dmn%02ds\n" $minutes $modulo
	else
		typeset -i hours=$minutes/60
		typeset -i rem_mn=$(( minutes - hours*60 ))
		typeset -i rem_sec=$(( seconds - (hours*60*60 + rem_mn*60) ))
		printf "%dh%02dmn%02ds\n" $hours $rem_mn $rem_sec
	fi
}

#*> fmt_number <number>
#*> Format number english or french, use LANG to define the format.
#*>
function fmt_number
{
	typeset -r number=$1
	typeset -i len=${#number}
	len=len-1

	case "${LANG:0:2}" in
		fr)	car_group=" "
			;;

		*)	car_group=","
			;;
	esac

	typeset formatted
	typeset -i if=0
	while [ $len -ge 0 ]
	do
		mod=$(compute $if%3)
		[[ $if -ne 0 && $mod -eq 0 ]] && formatted=$car_group$formatted
		formatted=${number:$len:1}$formatted
		if=if+1
		len=len-1
	done

	echo $formatted
}

#*> fmt_kb2mb <size>
#*>	convert <size> in Kb to Mb and format.
function fmt_kb2mb
{
	typeset -ri kb=$1
	typeset -ri mb=kb/1024
	echo "$(fmt_number $mb)Mb"
}

#*> to_mb <size><unit>
#*> Convert size in Mb
#*>		Last digits of size is the unit
#*>		Unit : G, Gb, M, Mb, Kb or K
function to_mb
{
	typeset -r	arg=$1
	typeset -r	size_value=$(sed "s/.$//" <<< "$arg")

	case $arg in
		*G|*Gb|*GiB)
			compute -i "$size_value*1024"
			;;

		*M|*Mb|*MiB)
			echo $size_value
			;;

		*K|*Kb|*KiB)
			compute -i "$size_value/1024"
			;;

		*)
			compute -i "$size_value/1024/1024"
			;;
	esac
}

#*> Convert value $1 to bytes
#*> Units can be b,k,m or g (or upper case)
function convert_2_bytes
{
	typeset -r	str_value=$1
	typeset -r	last_car=${str_value:${#str_value}-1}

	typeset -i	value=-1

	case $last_car in
		b|B)
			value=${str_value:0:${#str_value}-1}
			;;

		k|kb|K|Kb|KiB)
			value=${str_value:0:${#str_value}-1}
			value=value*1024
			;;

		m|mb|M|Mb|MiB)
			value=${str_value:0:${#str_value}-1}
			value=value*1024*1024
			;;

		g|gb|G|Gb|GiB)
			value=${str_value:0:${#str_value}-1}
			value=value*1024*1024*1024
			;;

		*)	# Pas d'unité donc des bytes.
			value=$str_value
			;;
	esac

	echo $value
}

#*> Convert value $1 to better.
#*> Units can be b,k,m or g (or upper case)
#*>
#*> 1024K == 1Mb
#*> 1024M == 1Gb
function fmt_bytesU_2_better
{
	typeset -i bytes=$(convert_2_bytes $1)

	if [ $bytes -ge $(( 1024*1024*1024 )) ]
	then	# Gb
		echo "$(compute -l2 $bytes / 1024 / 1024 / 1024)Gb"
	elif [ $bytes -ge $(( 1024*1024 )) ]
	then	# Mb
		echo "$(compute -l2 $bytes / 1024 / 1024)Mb"
	elif [ $bytes -ge 1024 ]
	then	# Kb
		echo "$(compute -l2 $bytes / 1024)Kb"
	else
		echo "${bytes}b"
	fi
}

################################################################################
#	Fonctions inclassable
################################################################################

#*> return 0 if cmd $1 exists else return 1
function test_if_cmd_exists
{
	which $1 >/dev/null 2>&1
}

#*< get_initiator_for <db> <#node>
#*< return initiator name for <db> and node <#node>
function get_initiator_for
{
	typeset -r db=$1
	typeset -r num_node=$2

	printf "%s%s:%02d" $iscsi_initiator_prefix $db $num_node
}

#*> return 0 if rpm update available else return 1
#*> check update on server $1 (optional)
function test_if_rpm_update_available
{
	case $# in
		1)
			typeset -r server=$1

			exec_cmd -c "ssh -t root@$server 'yum check-update >/dev/null 2>&1'"
			[ $? -eq 100 ] && return 0 || return 1
			;;

		0)
			exec_cmd -c "yum check-update >/dev/null 2>&1"
			[ $? -eq 100 ] && return 0 || return 1
			;;

		*)
			error "$0 invalid parameter !"
			exit 1
			;;
	esac
}
