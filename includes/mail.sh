#!/bin/sh
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    mail.sh                                            :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: jlejeune <marvin@42.fr>                    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2014/02/13 02:09:37 by jlejeune          #+#    #+#              #
#    Updated: 2014/02/13 02:09:37 by jlejeune         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# Global variables
mail_project_name_regex="s/^(.*) \(.*\)$/\1/p"
sender=""
phone=""
email=""
location=""

# Sends mail to remaining corrections
# returns : No return

send_mail_corrections ()
{
	template=""
	ask_template "template"
	if [ ${?} -gt 1 ]
	then
		error "-> Error while selecting template."
		return
	fi
	send_mails "${corrections_regex}" "${correction_uid_regex}" "${correction_uid_regex2}" "${template}"
}

# Sends mail to remaining correctors
# returns : No return

send_mail_correctors ()
{
	template=""
	ask_template "template"
	if [ ${?} -gt 1 ]
	then
		error "-> Error while selecting template."
		return
	fi
	send_mails "${correctors_regex}" "${corrector_uid_regex}" "" "${template}"
}

# Asks user for template to use
# $1 : Variable name to store the template name
# returns : No return

ask_template ()
{
	files=`find "${templates_path}" -type f -name "*.pt" -exec basename {} .pt ';' | tr '\n' ' '`
	menu "Which template should I use ?" "Enter your choice : " "" ${files}
	choice=${?}
	i=0
	for tmp in ${files}
	do
		if [ ${i} -eq ${choice} ]
		then
			eval "${1}=${tmp}"
			return 0
		else
			i=`expr ${i} + 1`
		fi
	done
	eval "${1}=\"\""
	return 1
}

# Gets the current user informations and stores it in the global variables
# $1 : The template file content
# returns : 0 if an error occurred, 1 if all went fine

get_sender_infos ()
{
	if [ -z "${1}" ]
	then
		echo "usage: get_sender_infos \"template file content\""
		return 0
	fi
	template_content="${1}"
	sender="${login}"
	email="${login}@student.42.fr"
	phone=""
	location=""
	if echo "${template_content}" | grep -q "\${phone}" || echo ${template_content} | grep -q "\${location}"
	then
		echo "-> Getting your informations..."
		url="https://dashboard.42.fr/user/profile/${login}/"
		info "-> Sending request..."
		content=`curl -sL -b "${dashboard_cookies}" "${url}"`
		if echo "${content}" | grep -q "UID"
		then
			if echo "${template_content}" | grep -q "\${phone}"
			then
				info "-> Getting mobile phone..."
				regex="s/^.*<dt>Mobile<\/dt>[[:blank:]]+<dd>([0-9\ _+-]+)<\/dd>.*$/\1/p"
				mobile=`echo "${content}" | tr -d '\n' | sed -nE "${regex}"`
				if [ ! -z "${mobile}" ]
				then
					info "-> Mobile phone found."
					phone=`echo "${mobile}" | tr -d ' ' | sed 's/+33/0/g' | sed 's/.\{2\}/& /g' | sed 's/.$//'`
				else
					info "-> Cannot find mobile phone."
					error "-> Your mobile phone is needed by the template but cannot be found. Please edit the template."
					return 0
				fi
			fi
			if echo "${template_content}" | grep -q "\${location}"
			then
				info "-> Getting location..."
				regex="s/^.*<dt>Latest location<\/dt>[[:blank:]]+<dd>(e[[:digit:]]+r[[:digit:]]+p[[:digit:]]+)\.42\.fr.*<\/dd>.*$/\1/p"
				location=`echo "${content}" | tr -d '\n' | sed -nE "${regex}"`
				if [ -z "${location}" ]
				then
					info "-> Cannot find location."
					error "-> Your location is needed by the template but cannot be found. Please edit the template."
					return 0
				fi
			fi
		else
			error "-> Unable to get your informations. Please retry."
			return 0
		fi
	fi
	return 1
}

# Sends a mail
# $1 : The project name
# $2 : The content
# $3 : The sender uid
# $4 : The receiver uid

send_mail ()
{
	if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
	then
		echo "usage: send_mail \"project name\" \"content\" \"sender uid\" \"receiver uid\""
		return
	fi
	echo "-> Sending mail to \033[4m${4}\033[0m"
	subject="Correction du projet ${1} - ${3}"
	if echo "${2}" | grep -q "<html>"
	then
		subject=`echo "${subject}\nContent-Type: text/html"`
	fi
	mail=`echo "${2}" | mail -s "${subject}" "${4}@student.42.fr" -f "${3}@student.42.fr" -F "${3}"`
	if [ ${?} == 1 ]
	then
		error "-> Error while sending mail."
	else
		success "-> Done."
	fi
}

# Sends mails
# $1 : Regular expression to discern projects
# $2 : Regular expression to get uids from source code
# $3 : Same as $2
# $4 : Mail template to use
# returns : No return

send_mails ()
{
	if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${4}" ]
	then
		echo "usage: send_mails \"projects regex\" \"source lines regex\" \"second source lines regex\" \"template\""
		return
	fi
	template=`cat "${templates_path}/${4}.pt"`
	template_return=${?}
	if [ -z "${template}" ] || [ ${template_return} == 1 ]
	then
		error "-> Cannot open template file."
		return
	fi
	ask "-> Should I send you a testing e-mail with this template ?" "n"
	response=${?}
	if [ ${response} -eq 1 ]
	then
		name="test_user"
		sender="${login}"
		phone="0600000000"
		email="test_user@student.42.fr"
		location="bocal-wtf"
		project="ProjetDeTest"
		template_eval=`eval "echo \"${template}\""`
		send_mail "${project}" "${template_eval}" "${login}" "${login}"
		ask "-> Would you like to send the real mails now ?" "y"
		response=${?}
		if [ ${response} -eq 0 ]
		then
			return
		fi
	fi
	echo "-> Connecting to intranet."
	connect_to_intra
	intra=${?}
	echo "-> Connecting to dashboard."
	connect_to_dashboard
	dashboard=${?}
	if [ ${intra} == 1 ] && [ ${dashboard} == 1 ]
	then
		get_sender_infos "${template}"
		sender_infos_return=${?}
		if [ ${sender_infos_return} == 1 ]
		then
			if [ ! -z "${sender}" ] || [ ! -z "${email}" ] || [ ! -z "${phone}" ] || [ ! -z "${location}" ]
			then
				echo "-> The template will be filled with the following informations :"
				if [ ! -z "${sender}" ]
				then
					echo "\tsender : ${sender}"
				fi
				if [ ! -z ${email} ]
				then
					echo "\temail : ${email}"
				fi
				if [ ! -z "${phone}" ]
				then
					echo "\tphone : ${phone}"
				fi
				if [ ! -z "${location}" ]
				then
					echo "\tlocation : ${location}"
				fi
				ask "Are these informations correct ?" "y"
				response=${?}
				if [ ${response} == 0 ]
				then
					return
				fi
			else
				echo "-> Your email doesn't contain any of your personal details (name, email, phone or location)."
				response=""
				ask "Do you want to send it anyway ?" "y"
				response=${?}
				if [ ${response} == 0 ]
				then
					return
				fi
			fi
		else
			return
		fi
		info "-> Loading intranet index page."
		content=`curl -sL -b "${intranet_cookies}" "https://intra.42.fr"`
		info "-> Reading page source..."
		i=0
		block=0
		project=""
		while read -r line
		do
			if [ -z "${project}" ]
			then
				project=`echo "${line}" | sed -nE "${1}"`
				if [ ${block} == 0 ] && [ ! -z "${project}" ]
				then
					echo "\n ${project}"
					project=`echo ${project} | sed -nE "${mail_project_name_regex}"`
					block=`expr ${block} + 1`
				fi
			fi
			if [ ${block} == 1 ] && echo "${line}" | grep -q "<ul>"
			then
				block=`expr ${block} + 1`
			fi
			if [ ${block} == 2 ]
			then
				if echo "${line}" | grep -q "</ul>"
				then
					block=0
					project=""
				fi
				if echo "${line}" | grep -q "devez"
				then
					uid=`echo "${line}" | sed -nE "${2}"`
					if [ -z "${uid}" ] && [ ! -z "${3}" ]
					then
						uid=`echo "${line}" | sed -nE "${3}"`
					fi
					if [ ! -z "${uid}" ]
					then
						name="${uid}"
						template_eval=`eval "echo \"${template}\""`
						send_mail "${project}" "${template_eval}" "${login}" "${name}"
						i=`expr ${i} + 1`
					fi
				fi
			fi
		done <<< "${content}"
		if [ ${i} == 0 ]
		then
			error "-> No peer corrections available."
		fi
	fi
}
