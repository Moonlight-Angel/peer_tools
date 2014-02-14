#!/bin/sh
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    utils.sh                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <marvin@42.fr>                    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/02/13 02:10:56 by jlejeune          #+#    #+#              #
#    Updated: 2014/02/13 02:10:56 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Displays a success message on standard output
# $1 : Message
# returns : No return

success ()
{
	if [ -z "${1}" ]
	then
		echo "usage: success \"message\""
		return
	fi
	echo "\033[32m${1}\033[0m"
}

# Displays an error message on error output
# $1 : Message
# returns : No return

error ()
{
	if [ -z "${1}" ]
	then
		echo "usage: error \"message\""
		return
	fi
	echo "\033[31m${1}\033[0m" >&2
}

# Displays an info message on standard output if verbose mode enabled
# $1 : Message
# returns : No return

info ()
{
	if [ -z "${1}" ]
	then
		echo "usage: info \"message\""
		return
	fi
	if [ ${verbose} == 1 ]
	then
		echo "\033[94m${1}\033[0m"
	fi
}

# Ask a question with two possible responses : Yes or No
# $1 : Question
# $2 : Default response (y/n)
# returns : 0 or 1 for No or Yes response

ask ()
{
	if [ -z "${1}" ] || [ -z "${2}" ]
	then
		echo "usage: ask \"question\" [default [y/n]]"
		return
	fi
	question="${1}"
	default="${2}"
	yn=""
	while [ "${yn}" = "" ]; do
		if [ "${default}" = "y" ]; then
			echo "${question} [Y/n] : \c"
		elif [ "${default}" = "n" ]; then
			echo "${question} [y/N] : \c"
		else
			echo "${question} [y/n] : \c"
		fi
		read yn
		yn=`echo "${yn}" | tr '[:upper:]' '[:lower:]'`
		if [ "${yn}" = "yes" ] || [ "${yn}" = "y" ]; then
			return 1
			break
		elif [ "${yn}" = "no" ] || [ "${yn}" = "n" ]; then
			return 0
			break
		elif [ "${yn}" = "" ] && [ "${default}" != "" ]; then
			if [ "${default}" = "y" ]; then
				return 1
				break
			elif [ "${default}" = "n" ]; then
				return 0
				break
			else
				yn=""
			fi
		else
			yn=""
		fi
	done
}

# Displays a menu with passed header, prompt, options and replies
# $1 : Header value
# $2 : Prompt value
# $3 : Variable name for multi-replies, empty for single reply
#      (if multi-replies enabled, result is returned in passed variable name)
# $4 : List of menu options
# returns : No return

menu ()
{
	if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${4}" ]
	then
		echo "usage: menu \"header\" \"prompt\" \"multi replies\" \"options\""
		return
	fi
	header="${1}"
	prompt="${2}"
	multi=0
	var_name=""
	if [ ! -z "${3}" ]
	then
		multi=1
		var_name="${3}"
	fi
	shift 3
	options=("${@}")
	choice=""
	choices=""
	i=1
	while [ -z "${choice}" ]
	do
		echo "-> ${header}"
		echo "-----------------------------------------------------"
		for option in "${options[@]}"
		do
			echo "   ${i} - ${option}"
			i=`expr ${i} + 1`
		done
		echo "-----------------------------------------------------"
		i=1
		if [ ${multi} == 1 ]
		then
			echo "-> Multiple options are possible, separate them with a space."
		fi
		echo "-> ${prompt}\c"
		read choice
		if [ ! -z "${choice}" ] && [ "${choice}" == "clear" ]
		then
			choice=""
			clear
		elif [ -z "${choice}" ] || [ "${choice}" = "0" ]
		then
			error "-> Invalid option."
			choice=""
		else
			if [ ${multi} == 1 ]
			then
				if [ `echo "${choice}" | tr -d '[:digit:] ' | wc -w` -gt 0 ]
				then
					error "-> Invalid options."
					choice=""
				else
					for op in ${choice}
					do
						if [ "${op}" -le "0" ] || [ -z "${options[${op} - 1]}" ]
						then
							error "-> Invalid option : '${op}'."
							choices=""
							choice=""
						else
							if [ -z "${choices}" ]
							then
								choices="`expr ${op} - 1`"
							else
								choices="${choices} `expr ${op} - 1`"
							fi
						fi
					done
					if [ ! -z "${choices}" ]
					then
						eval "${var_name}=\"${choices}\""
					fi
				fi
			else
				if [ `echo "${choice}" | tr -d '[:digit:]' | wc -w` -gt 0 ] || [ -z "${options[${choice} - 1]}" ]
				then
					error "-> Invalid option."
					choice=""
				else
					return `expr ${choice} - 1`
				fi
			fi
		fi
	done
}

# Checks for updates in the tool folder
# [$1] : 1 for silent mode, 0 for verbose mode
# returns : No return

check_updates ()
{
	silent=0
	if [ ! -z ${1} ] && [ ${1} == 1 ]
	then
		silent=1
	fi
	cd ${script_path} > /dev/null 2>&1
	if [ ${silent} == 0 ]
	then
		echo "-> Fetching the latest changes from the git..."
	fi
	git fetch -q origin
	if [ ${silent} == 0 ]
	then
		echo "-> Checking if there is some update to install..."
	fi
	diff=`git cherry master origin/master`
	if [ -z "${diff}" ]
	then
		if [ ${silent} == 0 ]
		then
			success "-> No updates available."
		fi
	else
		success "-> Updated are available !"
		echo "-> Latest update : `git show master..origin/master -n 1 -s --format=%B`"
		ask "-> Would you like to install the update ?" "y"
		if [ ${?} == 1 ]
		then
			echo "-> Installing..."
			git reset -q --hard
			git pull -q
			success "-> Update done, enjoy !"
			cd - > /dev/null 2>&1
			exit
		fi
	fi
	cd - > /dev/null 2>&1
}

# Makes fclean in each subfolder
# returns : No return

recursive_fclean ()
{
	echo "-> This option does \"make fclean\" in each subfolder of the folder you're in."
	echo "-> It cleans your corrections and reduces the corrections folder weight."
	echo "-> Make sure you are in your corrections folder for this option to work."
	ask "-> Do you want to clean your corrections folder ?" "y"
	response=${?}
	if [ ${response} == 1 ]
	then
		path=`pwd`
		if [ ! -z "${path}" ]
		then
			echo "-> You are actually in '${path}'."
			ask "-> Is this your corrections folder ?" "y"
			response=${?}
			if [ ${response} == 1 ]
			then
				`find . ! -path '*/\.*' -type d -exec make -C "{}" fclean \; > /dev/null 2>&1`
				success "-> Done !"
			else
				error "-> Aborted."
			fi
		else
			error "-> Cannot find current folder, aborting."
		fi
	else
		error "-> Aborted."
	fi
}

# Removes .git folder in each subfolder
# returns : No return

remove_git_folders ()
{
	echo "-> This option removes .git folder in each subfolder of the folder you're in."
	echo "-> Make sure you are in your corrections folder for this option to work."
	ask "-> Do you want to remove .git folders ?" "y"
	response=${?}
	if [ ${response} == 1 ]
	then
		path=`pwd`
		if [ ! -z "${path}" ]
		then
			echo "-> You are actually in '${path}'."
			ask "-> Is this your corrections folder ?" "y"
			response=${?}
			if [ ${response} == 1 ]
			then
				`find . -type d -name ".git" -exec rm -rf "{}" \; > /dev/null 2>&1`
				success "-> Done !"
			else
				error "-> Aborted."
			fi
		else
			error "-> Cannot find current folder, aborting."
		fi
	else
		error "-> Aborted."
	fi
}

# Say bye bye
# returns : No return

bye_bye ()
{
	success "-> Bye bye !"
	exit
}
