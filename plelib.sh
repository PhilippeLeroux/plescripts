# vim: ts=4:sw=4

[ ! -z $plelib_banner ] && return 0 || true

#LANG=en_US.UTF-8
umask 0002

################################################################################
#	Initialisation de la lib.
################################################################################

typeset -ri	plelib_release=4
typeset -r	plelib_banner=$(printf "plelib V%02d" $plelib_release)

#*> $1 title or default
function set_terminal_title
{
	if [ "$1" == "default" ]
	then
		echo -ne "\033]30;$term_default_title\007"
	else
		echo -ne "\033]30;$1\007"
	fi
}

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
	ITALIC="\e[3m"
	STRIKE="\e[9m"

	#	Clear End Of Line
	CEOL="\e[K"

	if [ ! -v OK ]
	then # Le flag +r ne fonctionne pas, mais ce n'est pas gênant DISABLE n'est plus utilisé.
		typeset -gr OK="${GREEN}ok${NORM}"
		typeset -gr	KO="${RED}ko${NORM}"
	fi
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

	if [ ! -v OK ]
	then # Le flag +r ne fonctionne pas, mais ce n'est pas gênant DISABLE n'est plus utilisé.
		typeset -gr OK="ok"
		typeset -gr	KO="ko"
	fi
}

#	============================================================================
#	Gestion de la log.

#	Valeurs possible : ENABLE | DISABLE | FILE
#	Par défault ENABLE
#	DISABLE est utile pour les scripts lancés par systemd au démarrage ou arrêt.
[ x"$PLELIB_OUTPUT" == x ] && typeset PLELIB_OUTPUT=ENABLE || true

[ "$PLELIB_OUTPUT" == DISABLE ] && disable_markers || enable_markers

typeset -r	PLELOG_ROOT=~/plescripts/logs
if [ ! -d $PLELOG_ROOT ]
then
	mkdir $PLELOG_ROOT >/dev/null 2>&1
	chmod ug=rwx,o=rx $PLELOG_ROOT >/dev/null 2>&1
fi

#	Un répertoire de log par jour.
typeset -r PLELOG_PATH=$PLELOG_ROOT/$(date +"%Y-%m-%d")

#	Lecture du nom du script appelant.
typeset	-r PLESCRIPT_NAME=${0##*/}

#*> Si le script est lancé par l'utilisateur oracle, la log, déclenchée par
#*> ple_enable_log est copié dans ~/log
function move_log_to_server
{
	[ x"$PLELIB_LOG_FILE" == x ] && return 0 || true

	typeset -r local_log_path=$HOME/log/$(date +"%Y-%m-%d")

	# Sauvegarde la log sur le serveur.
	[ ! -d $local_log_path ] && mkdir -p $local_log_path || true

	cp "$PLELIB_LOG_FILE" $local_log_path
	clean_log_file "$local_log_path/${PLELIB_LOG_FILE/$PLELOG_PATH\/}"

	LN
	info "log ${PLELIB_LOG_FILE/$PLELOG_PATH\/} copied to $local_log_path"
	LN
}

#*> $1 nom de la log sans le chemin (facultatif), par défaut nom du script appelant
#*> ou/et -params $*
#*> Exemple : ple_enable_log -params $*
function ple_enable_log
{
	if [[ "$#" -eq 0 || "$1" == "-params" ]]
	then # Construit le nom de la log à partir du nom du script.
		PLELIB_LOG_FILE=$PLELOG_PATH/$(date +"%Hh%Mmn%S")_${USER}_on_$(hostname -s)_${PLESCRIPT_NAME%.*}.log
	else
		PLELIB_LOG_FILE="$PLELOG_PATH/$(date +"%Hh%Mmn%S")_${USER}_on_$(hostname -s)_$1"
		shift
	fi

	# Les markers sont activés avec FILE ou ENABLE, s'ils étaient désactivés ils
	# sont activés.
	[ "$PLELIB_OUTPUT" == DISABLE ] && enable_markers || true
	PLELIB_OUTPUT=FILE

	#	Le répertoire doit être créée !
	if [ ! -d $PLELOG_PATH ]
	then
		echo "mkdir $PLELOG_PATH"
		mkdir $PLELOG_PATH

		# common_user_name est définie dans global.cfg
		chown $common_user_name:users $PLELOG_PATH
		chmod ug=rwx,o=rx $PLELOG_PATH
		[ $? -ne 0 ] && exit 1 || true
	fi

	if [ ! -f $PLELIB_LOG_FILE ]
	then
		touch $PLELIB_LOG_FILE >/dev/null 2>&1
		chmod ug=rw,o=r $PLELIB_LOG_FILE >/dev/null 2>&1
		[ $? -ne 0 ] && exit 1 || true
	fi

	if [[ $# -ne 0 && "$1" == "-params" ]]
	then
		shift
		info "Running : ${ME/$HOME/~} $*"
	fi

	[[ "$USER" == "oracle" && x"$PLELIB_LOG_FILE" != x ]] && trap move_log_to_server EXIT || true
}

#	============================================================================

if [ ! -v PLE_SHOW_EXECUTION_TIME_AFTER ]
then	# Temps en secondes, le temps d'exécution des commandes est affiché s'il
		# est supérieur à cette variable
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

[ x"$PLELIB_LOG_FILE" != x ] && trap clean_plelib_log_file EXIT || true

[ x"$EXEC_CMD_ACTION" == x ] && typeset EXEC_CMD_ACTION=NOP || true

################################################################################
#	Fonctions agissants ou donnant des informations sur le terminal.
################################################################################

#*> Hide cursor
function hide_cursor
{
	[ $PLELIB_OUTPUT != DISABLE ] && tput civis || true
}

#*> Show cursor
function show_cursor
{
	[ $PLELIB_OUTPUT != DISABLE ] && tput cnorm  || true
}

#*> print to stdout number of col for the terminal. if no terminal print 80
function term_cols
{
	[ $PLELIB_OUTPUT != DISABLE ] && tput cols || 80
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

#*> $1 server name
#*> exit 1 if curent server name is different.
#*> Variable $ME must be initialised with $0 (name of the script)
function must_be_executed_on_server
{
	typeset	-r on_host="$1"
	if [ $(hostname -s) != "$on_host" ]
	then
		error "Script ${ME##*/} must be executed on server $on_host"
		error "Current server is $(hostname -s)"
		exit 1
	fi
}

#*> $1 user list (separator space) Ex : "root" or "root grid"
#*> exit 1 if curent user name is different.
#*> Variable $ME must be initialised with $0 (name of the script)
function must_be_user
{
	typeset	-r	list_user="$1"
	if ! grep -qE "$list_user"<<<"$USER"
	then
		error "Script ${ME##*/} must be executed by user $list_user"
		error "Current user is $USER"
		exit 1
	fi
}

#*< Used by fonctions info, warning and error.
#*< Action depand of PLELIB_OUTPUT
#*<		DISABLE : no visual effects.
#*<		ENABLE	: visual effects
#*<		FILE	: write into $PLELIB_LOG_FILE without any effects and canal 1 with visual effects.
function my_echo
{
	typeset	EOL="\n"
	[ "$1" == "-n" ] && EOL="" && shift || true
	typeset -r	color="$1"
	typeset		symbol="$2"
	[ "$symbol" == no_symbol ] && symbol="" || true
	shift 2

	# Laisser les 2 lignes, sinon l'affichaged de MSG est foireux.
	typeset	MSG="$@"
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
	my_echo "${RED}${BLINK}" "✗" " $@"
}

#*> Print warning message
function warning
{
	my_echo "${LGREEN}${INVERT}" "<" " $@"
}

#*> Affiche les informations de debug.
#*> Actif uniquement si la variable DEBUG_MODE==ENABLE est définie.
#*> Fonctionne sur le même principe que info.
function debug
{
	[ "$DEBUG_MODE" != ENABLE ] && return 0

	typeset	first_arg=""
	typeset	symbol="dbg"
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

	my_echo $first_arg "${BLUE}" "$symbol" " $*"
}

#*>	Print normal message
#*> Options
#*>   -n no new line
#*>   -f don't print info marker. (Useful after info -n)
function info
{
	typeset	first_arg=""
	typeset	symbol="# "
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
	[ $# -eq 0 ] && typeset	car="=" || typeset  car="$1"

	if [ "$PLELIB_OUTPUT" == DISABLE ]
	then
		info $(fill "$car" 77)
	else
		info $(fill "$car" $(tput cols)-3)
	fi
}

#*> New line
function LN
{
	my_echo "${NORM}" ""
}

#*> Paramètres :
#*>
#*> -reply_list="y n" liste des réponses séparées par un espace, par défaut "y n"
#*>    * Pour la touche 'return' utiliser -reply_list=CR
#*>    * Maximum 3 réponses possibles.
#*>
#*> -print="y/n ?" les réponses à afficher, par défaut "y/n ?"
#*>
#*> Les autres paramètres forment la question.
#*>
#*>	Codes retours :
#*>		0	pour la première réponse.
#*>		1	pour la seconde réponse.
#*>		3	pour la troisième réponse.
#*>
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
		typeset	-i  start_s=$SECONDS
		typeset	    keyboard
		read keyboard</dev/tty
		info "$keyboard"	# Affiche la touche pressée.
		typeset -i diff_s=$(( SECONDS - start_s ))
		if [ $diff_s -gt 60 ]
		then
			info "Idle time $(fmt_seconds $diff_s)"
			LN
		fi

		case "$keyboard" in
			'')
				[ "$yes_reply" == "CR" ] && return 0 || true
				error "'$keyboard' invalid."
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
#*> Si l'utilisateur répond non (la 2ième réponse) le script est terminé par un exit 1
function confirm_or_exit
{
	ask_for "$@"
	[ $? -eq 1 ] && exit 1 || return 0
}

################################################################################
#	Fonctions permettant d'exécuter des commandes ou scripts.
################################################################################

#*>	Modifie '$@' et affiche le résultat sur stdout.
#*>		Remplace le chemin correspondand à HOME par $HOME
#*>		Remplace le chemin correspondand à TNS_ADMIN par $TNS_ADMIN
#*>		Remplace le chemin correspondand à ORACLE_HOME par $ORACLE_HOME
#*>		Remplace le chemin correspondand à ORACLE_BASE par $ORACLE_BASE
function replace_paths_by_shell_vars
{
	typeset s=$(sed "s,$HOME,\$HOME,"<<<"$@")

	[ -v TNS_ADMIN ] && s=$(sed "s,$TNS_ADMIN,\$TNS_ADMIN,"<<<"$s") || true

	[ -v ORACLE_HOME ] && s=$(sed "s,$ORACLE_HOME,\$ORACLE_HOME,"<<<"$s") || true

	[ -v ORACLE_BASE ] && s=$(sed "s,$ORACLE_BASE,\$ORACLE_BASE,"<<<"$s") || true

	echo "$s"
}

#*< Convertie les tabulations et supprime les espaces en trop de "$@"
function simplify_cmd
{
	echo "$*" | tr -s '\t' ' ' | tr -s [:space:]
}

#*< Affiche sur stdout le timestamp à utiliser pour l'exécution d'une commande.
#*< Si la longueur d'affichage change adapter la variable ple_param_margin
function get_tt
{
	date +"%H:%M:%S"
}

#*> Fake exec_cmd command
#*> Command printed but not executed.
#*> return :
#*>    1 if EXEC_CMD_ACTION = NOP
#*>    0 if EXEC_CMD_ACTION = EXEC
function fake_exec_cmd
{
	typeset -r	simplified_cmd=$(replace_paths_by_shell_vars "$*")
	case $EXEC_CMD_ACTION in
		NOP)
			my_echo "${YELLOW}" "${INVERT}nop  >${NORM} " "$simplified_cmd"
			return 1
			;;

		EXEC)
			my_echo "${YELLOW}" "${STRIKE}$(get_tt)>${NORM} " "$simplified_cmd"
			return 0
	esac
}

#*> $@ string
#*> print to stdout string without quotes ( ' or " )
function unquote
{
	typeset	string="$@"
	# Supprime la ' ou " du début si elle est présente.
	case "${string:0:1}" in
		"'"|"\"")
			string="${string:1}"
			;;
	esac

	# Supprime la ' ou " de fin si elle est présente.
	case "${string:${#string}-1:1}" in
		"'"|"\"")
			echo "${string:0:${#string}-1}"
			return
			;;
	esac

	echo "$string"
}

#*< $1|$@ commande, est utilisé par la fonction exec_cmd.
#*< Si la commande utilise ssh|sudo|su affiche sur stdout la commande appelée.
function shorten_command
{
	# Tokenize la commande passée en argument dans argv.
	typeset	-a	argv
	read -a argv <<<"$(unquote "$@")"

	case "${argv[0]}" in
		ssh|sudo|su)
			# Lecture de la commande exécutée par ssh|sudo|su
			:
			;;
		LANG=*)
			# call récursif avec LANG=* en premier paramètre, le second est la
			# commande.
			echo ${argv[1]}
			return 0
			;;
		*)
			# pas de ssh|sudo|su c'est la commande.
			echo ${argv[0]}
			return 0
			;;
	esac

	typeset -ri size=${#argv[@]}
	if [ $size -eq 1 ]
	then	# Il n'y a qu'une seule commande
		echo ${argv[0]}
		return 0
	fi

	typeset -i	argc=1
	# Passe tous les arguments de ssh|sudo|su : tout ce qui commence par un -
	typeset		arg
	while [ $argc -ne $size ]
	do
		arg=${argv[$argc]}
		[ "${arg:0:1}" != - ] && break || true

		((++argc))
	done

	# La commande est donc sur argc+1
	if [ $(( argc + 1 )) -eq $size ]
	then # Pas de commande c'est un ssh|sudo|su interactif
		echo "${argv[0]} (interactif)"
		return 0
	fi

	case "${argv[0]}" in
		su|sudo)
			typeset	-i	icmd=argc
			typeset		cmd=$(unquote ${argv[icmd]})
			((++argc))

			# Il n'y pas de façon générique pour détecter un compte.
			case "$cmd" in
				oracle|grid|root|$common_user_name)
					# passe le compte.
					((++icmd))
					((++argc))
					cmd=$(unquote ${argv[icmd]})
				;;
			esac

			# cas de su ... -c
			if [ "$cmd" == "-c" ]
			then
				((++icmd))
				cmd=$(unquote ${argv[icmd]})
				((++argc))
			fi
			;;

		ssh) # passe la chaîne de connexion.
			typeset	-i	icmd=argc+1
			typeset		cmd=$(unquote ${argv[icmd]})
			((++argc))
			;;
	esac

	# Passe tous les arguments de ssh|sudo|su : tout ce qui commence par un -
	typeset	arg
	while [ $argc -ne $size ]
	do
		arg=${argv[$argc]}
		[ "${arg:0:1}" != - ] && break || true
		((++argc))
	done

	case "$cmd" in
		LANG=*) # Passe LANG=*
			((++icmd))
			cmd=${argv[icmd]}
			((++argc))
			;;
	esac

	case "$cmd" in
		sudo|su)
			if [ "${argv[0]}" == "ssh" ]
			then
				echo "$(shorten_command "${argv[@]:icmd}") (ssh $cmd)"
			else
				echo "$(shorten_command "${argv[@]:icmd}") ($cmd)"
			fi
			return 0
			;;

		cd) # cd path && ou ;
			icmd=icmd+2	# se positionne après le répertoire.
			[ "${argv[icmd]}" == "&&" ] && ((++icmd)) || true
			echo "$(shorten_command "${argv[@]:icmd}") (${argv[0]})"
			return 0
			;;

		.) # . .bash_profile
			argc=argc+2
			case "${argv[$argc]}" in
				";"|"&&")
					#	. .bash_profile \; ....
					# or
					#	. .bash_profile && ....
					((++argc))
					;;
			esac

			if [ "${argv[argc]}" == "cd" ]
			then
				argc=argc+2 # Passe la commande cd 'répertoire'
				[ "${argv[argc]}" == "&&" ] && ((++argc)) || true
			fi

			echo "$(shorten_command "${argv[@]:argc}") (${argv[0]})"
			return 0
			;;
	esac

	echo "$cmd (${argv[0]})"
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
#*>		-ci like -c.
#*>		-h  hide command except on error.
#*>		-hf like -h.
#*>		-novar path not replaced by variable name.
#*>
#*> Show execution time after PLE_SHOW_EXECUTION_TIME_AFTER seconds
#*>
#*> Les paramètres -ci et -hf ne sont plus pris en compte (je ne sais pas pourquoi)
#*> mais ils sont encore utilisés dans plusieurs scripts. Leurs effets étaient
#*> uniquement sur l'affichage.
#*> En regardant l'historique git, les actions de ces paramètres ont disparus il
#*> 4 mois (date du reset du repository) donc je ne sais pas vraiment ce qui
#*> c'est passé avec ces paramètres.
#*> Morale de l'histoire ne jamais faire de reset de dépôt :(
function exec_cmd
{
	# Mémo : ne jamais utiliser $1 $2 ... mais uniquement $*
	#	exec_cmd ls -rtl	est valable
	#	exec_cmd "ls -rtl"	l'est aussi.
	typeset force=NO
	typeset continue_on_error=NO
	typeset hide_command=NO
	typeset path_2_var=YES

	while [ 0 -eq 0 ]	# forever
	do
		case "$1" in
			"-f")
				shift
				if [ $EXEC_CMD_ACTION == NOP ]
				then
					EXEC_CMD_ACTION=EXEC
					force=YES
				fi
				;;

			"-cont"|"-c")	# Affiche un message si la commande échoue
				shift
				continue_on_error=YES
				;;

			"-ci")			# NOP : n'est plus utilisé.
				shift
				continue_on_error=YES
				;;

			"-h")
				shift
				hide_command=YES
				;;

			"-hf")			# NOP : n'est plus utilisé.
				shift
				hide_command=YES
				;;

			"-novar")
				shift
				path_2_var=NO
				;;

			*)
				break		# exit while.
				;;
		esac
	done

	typeset -i	eval_return

	if [ $path_2_var == YES ]
	then
		typeset simplified_cmd=$(replace_paths_by_shell_vars $(simplify_cmd $*))
	else
		typeset simplified_cmd=$(simplify_cmd $*)
	fi

	simplified_cmd=$(escape_symbol_nl "$simplified_cmd")

	case $EXEC_CMD_ACTION in
		NOP)
			my_echo "${YELLOW}" " nop > " "$simplified_cmd"
			;;

		EXEC)
			[ $force == YES ] && typeset -r COL=$RED || typeset -r COL=$YELLOW
			[ $hide_command == NO ] && my_echo "$COL" "$(get_tt)> " "$simplified_cmd" || true

			typeset -ri eval_start_at=$SECONDS
			if [ x"$PLELIB_LOG_FILE" == x ]
			then
				eval "$*"
				eval_return=$?
			else
				eval "$*" 2>&1 | tee -a $PLELIB_LOG_FILE
				eval_return=${PIPESTATUS[0]}

				#	ksh workaround, mais ksh n'est normalement plus utilisé :
				[ x"$eval_return" == x ] &&	eval_return=0 || true
			fi

			typeset -ri eval_duration=$(( SECONDS - eval_start_at ))
			if [ $eval_duration -gt $PLE_SHOW_EXECUTION_TIME_AFTER ]
			then
				typeset -r shortened_cmd=$(shorten_command "$simplified_cmd")
				my_echo "${YELLOW}" "$(get_tt)< " "$shortened_cmd running time : $(fmt_seconds $eval_duration)"
			fi

			if [ $eval_return -ne 0 ]
			then
				if [[ $eval_duration -lt $PLE_SHOW_EXECUTION_TIME_AFTER && $hide_command == YES ]]
				then
					# Si la commande a durée plus de PLE_SHOW_EXECUTION_TIME_AFTER
					# la commande simplifiée a été affichée, sur une erreur affichage
					# de la commande complète.
					my_echo "$COL" "$(get_tt)> " "$simplified_cmd" || true
				fi

				if [ x"$shortened_cmd" == x ]
				then
					typeset -r shortened_cmd=$(shorten_command "$simplified_cmd")
				fi

				case "$continue_on_error" in
					NO)
						[ $force == YES ] && EXEC_CMD_ACTION=NOP || true # Utile, si le script appelant continue sur une erreur.
						error "$shortened_cmd return $eval_return"
						exit 1
						;;
					YES)
						warning "$shortened_cmd return $eval_return, continue..."
						;;
				esac
			fi
			;;

		*)
			error "Bad value for EXEC_CMD_ACTION = '$EXEC_CMD_ACTION'"
			exit 1
			;;
	esac

	[ $force == YES ] && EXEC_CMD_ACTION=NOP || true

	return $eval_return
}

typeset -a	ple_dyn_param_cmd
typeset -i	ple_dyn_param_max_len=0
#	10	correspond à la largeur de l'horodatage devant les commandes exécutées,
#		exemple : '10:44:01>'
#	4	les paramètres seront 'tabulés' de 4 espaces par rapport à la commande.
typeset -ri	ple_param_margin=$((4+10))

#*>	[-nvsr]	No Var Shell Replacement
#*> $@ parameter to add.
function add_dynamic_cmd_param
{
	if [ "$1" == "-nvsr" ]
	then
		shift
		typeset -r param="$@"
	else
		typeset -r param="$(replace_paths_by_shell_vars "$*")"
	fi

	typeset -ri	len=${#param}
	ple_dyn_param_cmd+=( "$param" )

	if [[ $len -gt $ple_dyn_param_max_len &&
					$(( len + ple_param_margin + 4 + 2 )) -lt $(term_cols) ]]
	then
		ple_dyn_param_max_len=$len
	fi
}

#*> run command '$@' with parameters define by add_dynamic_cmd_param
#*>		[-confirm] a prompt is printed to confirm or not execution.
#*>		[-c] continue on error.
function exec_dynamic_cmd
{
	typeset confirm=no
	typeset farg
	while [ 0 -eq 0 ]
	do
		case "$1" in
			"-confirm")
				confirm=yes
				shift
				;;
			"-c")
				farg="-c"
				shift
				;;
			*)
				break;
				;;
		esac
	done

	typeset -r cmd_name=$(replace_paths_by_shell_vars $@)

	ple_dyn_param_max_len=ple_dyn_param_max_len+2

	#	4 correspond à la largeur de la tabulation ajoutée devant les paramètres,
	#	le but étant d'aligner le \ derrière la commande aux \ derrières les paramètres.
	#	Ex :
	#	10h40> ma_commande  \
	#              -x=42    \
	#			   -t
	typeset	-ri	l=ple_dyn_param_max_len+4
	fake_exec_cmd "$(printf "%-${l}s%s\n" "$cmd_name" "\\\\")"

	#	Affiche les paramètres de la commande :
	for (( i=0; i < ${#ple_dyn_param_cmd[@]}; ++i ))
	do
		[ $i -ne 0 ] && info -f "\\\\"	# Affiche \ à la fin de la ligne précédente.
		info -f -n "$(printf "%${ple_param_margin}s%-${ple_dyn_param_max_len}s" " " "${ple_dyn_param_cmd[$i]}")"
	done
	LN

	if [ $EXEC_CMD_ACTION == EXEC ]
	then
		[ $confirm == yes ] && confirm_or_exit "Continue" || true

		exec_cmd $farg -h $cmd_name "${ple_dyn_param_cmd[@]}"
		typeset	-ri	exec_cmd_return=$?
	else
		[ $confirm == yes ] && info "Continue yes (parameter -emul set)" || true
		typeset	-ri	exec_cmd_return=0
	fi

	unset ple_dyn_param_cmd
	ple_dyn_param_max_len=0

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
		error "File '$1' not exist."
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
		error "Directory '$1' not exist."
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

#*<	Test if a variable exists, format ^var\s{0,}=\s{0,}value
#*<	1	variable name
#*<	2	file name
function exists_var
{
	grep -qE "^${1}\s{0,}=\s{0,}" "$2"
}

#*< change_value <var> <value> <file>
#*<	Format ^var\\s*=\\s*value
function change_value
{
	typeset -r var_name="$(escape_slash "$1")"
	typeset -r file="$3"

	if [ "$2" == "empty" ]
	then
		typeset -r new_val=""
		info "Remove value for : $var_name"
	else
		typeset -r new_val="$(escape_slash "$2")"
		info "Update value : $var_name = $2"
	fi
	exec_cmd "sed -i 's/^\(${var_name}\s\{0,\}=\s\{0,\}\).*/\1$new_val/' $file"
	LN
}

#*< add_new_variable <var> <value> <file>
#*< Format : var=value
#*< If <value> == empty no value specified.
function add_new_variable
{
	typeset -r var_name="$1"
	[ "$2" == "empty" ] && typeset -r new_val="" || typeset -r new_val="$2"
	typeset -r file="$3"

	info "Add new variable : $var_name=$new_val"
	exec_cmd "echo \"$var_name=$new_val\" >> $file"
	LN
}

#*> update_variable <var> <value> <file>
#*>	Update variable <var> from file <file> with value <value>
#*> If variable doesn't exist, it's added.
#*> If value = empty reset value but not remove variable.
#*>
#*<	Format ^var\\\s*=\\\s*value
#*>
#*> If file doesn't exist script aborted.
function update_variable
{
	[ $EXEC_CMD_ACTION == EXEC ] && exit_if_file_not_exists "$3" "Call function update_variable $1 $2" || true

	typeset -r var_name="$1"
	typeset -r var_value="$2"
	typeset -r file="$3"

	if exists_var "$var_name" "$file"
	then
		change_value "$var_name" "$var_value" "$file"
	else
		add_new_variable "$var_name" "$var_value" "$file"
	fi
}

#*> remove_variable <var> <file>
#*>
#*> Remove variable <var> from file <file>
#*>		Format ^var\\\s*=.*
#*>
#*> If file doesn't exist script aborted.
function remove_variable
{
	[ $EXEC_CMD_ACTION == EXEC ] && exit_if_file_not_exists "$2" "Call function remove_variable" || true

	typeset -r var_name=$(escape_slash "$1")
	typeset -r file="$2"
	if exists_var "$var_name" "$file"
	then
		info "Remove variable : $var_name"
		exec_cmd "sed -i '/^${var_name}\s*=.*$/d' $file"
	else
		info "remove_variable : variable '$var_name' not exists in $file"
	fi
}

################################################################################
#	Fonctions permettant de tester les arguments des scripts.
################################################################################

#*> exit_if_param_undef <var> [message]
#*>
#*> Script aborted if var == undef or == -1 or empty
function exit_if_param_undef
{
	typeset -r var_name=$1
	typeset -r var_value=$(eval echo \$$var_name)

	if [[ "$var_value" == "undef" || "$var_value" == "-1" || x"$var_name" == x ]]
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
		error "-$var_name=$var_value invalid, values : $val_list"
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
	echo "${@//\%/%%}"
}

#*> Escape \\\n from $@
function escape_symbol_nl
{
	sed "s/\\\n/\\\\\\\n/g"<<<"$@"
}

#*> Escape " from $@
function escape_2xquotes
{
	echo ${@//\"/\\\"}
}

#*> Escape / from $@
function escape_slash
{
	echo ${@//\//\\/}
}

#*> Escape \\\ from $@
function escape_anti_slash
{
	echo ${@//\\/\\\\}
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

#*> fill <car> <#>
#*> Print to stdout a buffer filled with #characteres car
function fill
{
	typeset -r	car="$1"
	typeset -ri	nb=$2

	typeset		buffer
	typeset	-i	count=0
	while [ $count -lt $nb ]
	do
		buffer=$buffer$car
		((++count))
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
	typeset -ri max_secs=$1
	[ $# -eq 2 ] && typeset -r suffix="$2" || typeset -r suffix

	typeset -i	secs=0
	typeset		backspaces
	typeset		buffer
	typeset		sticks_lt_5		# sticks en construction < 5
	typeset		sticks_image	# Tous les sticks précédents à afficher.

	case "$PLELIB_OUTPUT" in
		"ENABLE"|"FILE")
			hide_cursor

			while [ $secs -ne $max_secs ]
			do
				sleep 1
				((++secs))
				buffer=$(printf "${secs}/${max_secs}s")
				buffer="$buffer$suffix"

				if [[ $max_secs -lt 5 || $max_secs -gt 60 ]]
				then
					printf "$backspaces$buffer$CEOL"
					backspaces=$(fill "\b" ${#buffer})
				else
					if [[ $(( secs % 5 )) -eq 0 ]]
					then
						sticks_image="$sticks_image${STRIKE}||||${NORM} "
						sticks_lt_5=""
						printf "$backspaces$buffer $sticks_image$CEOL"
					else
						sticks_lt_5="$sticks_lt_5|"
						printf "$backspaces$buffer $sticks_image$sticks_lt_5$CEOL"
					fi
					backspaces=$(fill "\b" $((${#buffer}+1+secs)))
				fi
			done

			show_cursor

			[ "$PLELIB_OUTPUT" == "FILE" ] && printf "${max_secs}/${max_secs}s" >> $PLELIB_LOG_FILE

			if [[ $max_secs -lt 5 || $max_secs -gt 60 ]]
			then
				return ${#buffer}
			else
				return $(( ${#buffer}+1+secs ))
			fi
		;;

		"DISABLE")
			printf "${max_secs}s> "
			while [ $secs -ne $max_secs ]
			do
				printf "."
				sleep 1
				((++secs))
			done

			buffer="${max_secs}s>: "$(fill . $max_secs)
			if [ $# -eq 2 ]
			then
				printf " $suffix"
				buffer=$buffer" "$suffix
			fi

			return ${#buffer}
		;;
	esac
}

#*>	Temporisation pendant $1 secondes
#*>	$1 temps en secondes
#*>	$2 msg par défaut pas de message.
function timing
{
	typeset -ri secs=$1
	[ $# -eq 1 ] && typeset msg="" || typeset msg="$2 : "

	info -n "$msg"; pause_in_secs $secs; LN
}

ple_start=0
#*> script_start
#*> A appelé en début de script.
function script_start
{
	[ $ple_start -ne 0 ] && error "2x call : script_start" && exit 1
	ple_start=$SECONDS
}

#*> script_stop <nom du script>
#*> $1 est le nom du script
#*> $@ les autres paramètres sont des messages
#*> Affiche le temps écoulé depuis le dernier appel à script_start
#*> Doit être appelé en fin de script
function script_stop
{
	typeset	-r script_name=${1##*/}
	shift
	if [ $# -ne 0 ]
	then
		typeset -r msg="$script_name:$@"
	else
		typeset -r msg="$script_name:"
	fi

	typeset	-ri	total_seconds=$(( SECONDS - ple_start ))

	info "script $script_name running time : ${BOLD}$(fmt_seconds $total_seconds)${NORM}"

	[ ! -d ~/plescripts/tmp ] && mkdir ~/plescripts/tmp
	if [ -d ~/plescripts/tmp ]
	then	# Teste car si le mkdir du dessus échoue ne fait rien
		if [ ! -f ~/plescripts/tmp/scripts_chrono.txt ]
		then
			echo "Timestamp:script:id:seconds:fmt_seconds" > ~/plescripts/tmp/scripts_chrono.txt
		fi
		echo "$(date +%Y%m%d%H%M):$msg:$total_seconds:$(fmt_seconds $total_seconds)" >> ~/plescripts/tmp/scripts_chrono.txt
	fi
}

# La variable peut être exportée depuis le shell.
PAUSE=${PAUSE:-OFF}
#*< Sert pour le debuggage.
#*< Si des paramètres sont passés il sont affiché comme un message.
#*< Pour que la fonction soit active il faut positionner la variable PAUSE à ON
#*< $1 message (optionnel)
function test_pause
{
	if [ $PAUSE == ON ]
	then
		[ $# -ne 0 ] && info "$@"
		ask_for -reply_list=CR "Press enter to continue, Ctrl-C to abort."
		LN
	fi
}

################################################################################
#	Fonctions de formatage et de manipulation de nombres.
################################################################################

#*> Eval an arithmetic expression
#*> Flags
#*>    -l# : use real numbers with # number decimals
#*>    -i : remove all decimals
function compute
{
	typeset	bc_args=""
	typeset	scale=""
	typeset	return_int=no

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

	typeset	val=$(echo "$@" | bc $bc_args)
	[ x"$scale" != x ] && val=$(LANG=C printf "%.${scale}f" $val)
	[ $return_int == yes ] && echo ${val%%.*} || echo $val
}

#*> formate $1 seconds to the better format
function fmt_seconds
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

#*> Format number $1 english or french, use LANG to define the format.
function fmt_number
{
	typeset -r number=$1
	typeset -i len=${#number}
	len=len-1

	case "${LANG:0:2}" in
		fr)	typeset	-r	car_group=" "
			;;

		*)	typeset	-r	car_group=","
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

#*> Convert $1 in Mb
#*>		Last digits is the unit : G, Gb, M, Mb, Kb or K, b or B
function to_mb
{
	typeset -r	arg=$1
	typeset -r	size_value=$(sed "s/.$//" <<< "$arg")

	case $arg in
		*g|*G|*Gb|*GiB)
			compute -i "$size_value*1024"
			;;

		*m|*M|*Mb|*MiB)
			echo $size_value
			;;

		*k|*K|*Kb|*KiB)
			compute -i "$size_value/1024"
			;;

		*b|*B)
			compute -i "$size_value/1024/1024"
			;;

		*)
			echo "call to function 'to_mb $1' unit missing or invalid."
			exit 1
			;;
	esac
}

#*> Convert value $1 to bytes
#*> Units can be b,k,m or g (or upper case)
function to_bytes
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
function fmt_bytes_2_better
{
	typeset compute_arg="-l2"
	if [ "$1" == "-i" ]
	then
		compute_arg="-i"
		shift
	fi

	typeset -ri bytes=$(to_bytes $1)

	if [ $bytes -ge $(( 1024*1024*1024 )) ]
	then	# Gb
		echo "$(compute $compute_arg $bytes / 1024 / 1024 / 1024)Gb"
	elif [ $bytes -ge $(( 1024*1024 )) ]
	then	# Mb
		echo "$(compute $compute_arg $bytes / 1024 / 1024)Mb"
	elif [ $bytes -ge 1024 ]
	then	# Kb
		echo "$(compute $compute_arg $bytes / 1024)Kb"
	else
		echo "${bytes}b"
	fi
}

################################################################################
#	Fonctions inclassable
################################################################################

#*> $1 variable value
#*> return 0 if is a number, else return 1
function is_number
{
	[[ $1 =~ ^[0-9]+$ ]]
}

#*> return 0 if cmd $1 exists else return 1
function command_exists
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

#*> return 0 if rpm update available, else return 1
#*> [$1 -show] show all update
#*> check update on server $1 or $2 or local server if server name is missing.
function rpm_update_available
{
	if [ "$1" == "-show" ]
	then
		typeset -r show_updates=yes
		shift
	else
		typeset -r show_updates=ni
	fi

	case $# in
		1)
			typeset -r server=$1

			exec_cmd -hf "ssh -t root@$server 'yum makecache >/dev/null 2>&1'"
			exec_cmd -c -hf "ssh -t root@$server 'yum check-update >/dev/null 2>&1'"
			if [ $? -eq 100 ]
			then
				if [ $show_updates == yes ]
				then
					exec_cmd -c -hf "ssh -t root@$server 'yum check-update'"
				else
					info "$server update available."
				fi
				return 0
			else
				info "$server up to date."
				return 1
			fi
			;;

		0)
			exec_cmd -hf "yum makecache" >/dev/null 2>&1
			exec_cmd -c -hf "yum check-update >/dev/null 2>&1"
			if [ $? -eq 100 ]
			then
				if [ $show_updates == yes ]
				then
					exec_cmd -c -hf "yum check-update"
				else
					info "$(hostname -s) update available."
				fi
				return 0
			else
				info "$(hostname -s) up to date."
				return 1
			fi
			;;

		*)
			error "$0 invalid parameter !"
			exit 1
			;;
	esac
}

#*> print to stdout total os memory
function get_os_memory_mb
{
	free -m|grep "Mem:"|awk '{ print $2 }'
}

#*> [$1] -t# '#' is time out in ms, default 5s (5000ms)
#*> $1 or $2 message to notify (message is also displayed to stdout)
#*> Work if notify-send exists
function notify
{
	if [ "${1:0:2}" == "-t" ]
	then
		typeset -i notify_timeout=${1:2} #skip -t
		# Si -t n'est pas suivit d'un nombre alors notify_timeout vaut 0
		[ $notify_timeout -eq 0 ] && notify_timeout=100 || true
		shift
	else
		typeset -i notify_timeout=5000
	fi

	if command_exists notify-send
	then
		notify-send -t $notify_timeout -u low "PLESCRIPTS" "$1"
	fi

	info "$1"
}

debug "${RED}DEBUG MODE ENABLE${NORM}"
