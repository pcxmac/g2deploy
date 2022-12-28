#!/bin/bash
#
# MGET ISSUE, on HTTP MIRRORING PACKAGE.MIRRORS, THE SOURCE FILE CONVERTS TO A FOLDER (desired to be name of destination), THEN SOURCE FILE, OG. Where as I want just desired ... 
#
# ADD SUPPORT FOR STDOUT so as to PIPE to DECOMPRESSION ALGOs, etc...
#
#
#
#

function getSSH()
{
	echo "getSSH"
}

# needs passwordless-authorized key to stream through getRSYNC
function getRSYNC()
{
	local host="${*:?}"
	local waiting=1
	local rCode=""
	local pause=60
	local uri=""
	local destination="${2:?}"

	host="${host#*://}"
	#local local_move="$(echo ${host} | grep '^/')"

	# will be null if local_move 
	host="${host%%/*}"

	# ALLOW LOCAL RSYNC w/ rsync:/// , no host condition.

	while [[ "${waiting}" == 1 && -n "${host}" ]]
	do
		# timout introduced because some rsync servers will take forever and a day while generating directory of shares
		rCode="$(timeout 10 rsync -n "${host}":: 2>&1 | \grep 'Connection refused')"
        if [[ -z "${rCode}" ]]
		then
			if [[ -z "${destination}" ]]
			then
				uri="${1:?}"
				scp "${uri#*rsync://}" /dev/stdout
			else
				# local move ?
				if [[ -n ${host} ]]
				then
					rsync -a --no-motd --info=progress2 --rsync-path="sudo rsync" "$@" 
				else
					rsync -a --no-motd --info=progress2 --rsync-path="sudo rsync" "${@#*rsync://}"
				fi
			fi
			waiting=0
		else
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done

	# local move state, host="" & local_move = source $@ | rsync:/// is invalid according to rsync, so $@ must be pruned to reflect a hostless source
	# ex. string for @$ = "rsync:///var/lib/portage/patchfiles/ /tmp/output/" 
	# change to ${@rsync://#*/}

	if [[ -z ${host} ]]
	then
			rsync -a --no-motd --info=progress2 --rsync-path="sudo rsync" "${@#*rsync://}" 
	fi
	#echo $rCode
}


function getHTTP() 	#SOURCE	#DESTINATION #WGET ARGS
{
	local destination="${2:?}"
	local url="${1:?}"
	local waiting=1
	local httpCode=""
	local pause=60

	while [[ ${waiting} == 1 ]]
	do
		httpCode="$(wget -NS --spider "${url%\**}" 2>&1 | \grep "HTTP/" | awk '{print $2}' | \grep '200' | uniq)"
		if [[ "${httpCode}" == "200" ]]
		then
			if [[ -z ${destination} ]]
			then
				wget -O - --reject "index.*" --no-verbose --no-parent "${url}" 2>/dev/null
			else
				wget -r --reject "index.*" --no-verbose --no-parent "${url}" -P "${destination%/*}" --show-progress
			fi
			waiting=0
		else
			#ipCheck="$(ping ${url} -c 3 | grep "0 received")"
			#if [[ -n ${ipCheck} ]];then echo "."; fi
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done
	# better not to echo code, for streaming
	#echo $ftpCode
}

function getFTP()
{
	local destination="${2:?}"
	local url="${1:?}"
	local waiting=1
	local ftpCode=""
	local pause=60

	while [[ ${waiting} == 1 ]]
	do
		ftpCode="$(wget -NS --spider "${url%\**}" 2>&1 | \grep "No such file *."  | awk '{print $2}')"
		if [[ -z "${ftpCode}" ]]
		then
			if [[ -z ${destination} ]]
			then
				wget -O - --reject "index.*" --no-verbose --no-parent "${url}" 2>/dev/null
			else
				wget -r --reject "index.*" --no-verbose --no-parent "${url}" -P "${destination}" --show-progress
			fi
			waiting=0
		else
			#ipCheck="$(ping ${url} -c 3 | grep "0 received")"
			#if [[ -n ${ipCheck} ]];then echo "."; fi
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done
	# better not to echo code, for streaming
	#echo $ftpCode
}

function mget()
{

	#local url="$(echo "$1" | tr -d '*')"			# source_URL
	local destination="${2:?}"	# destination_FS
	#local args=$3
	local offset
	local host
	local _source
	local url="${1:?}" # source_URL

	echo "FUCK THIS SHIT !!!!" 2>&1

	case ${url%://*} in
		# local rsync only
		ftp*)
			if [[ -z ${destination} ]]
			then
				echo "$(getFTP ${url})"
			else
				getFTP "${url}" "${destination}"
				mv "${destination}/${url#*://}" "${destination}/"
				url=${url#*://}
				url=${url%%/*}
				rm "${destination:?}/${url:?}" -R
			fi
		;;
		http*)
			if [[ -z ${destination} ]]
			then
				echo "$(getHTTP ${url})"
			else
				getHTTP "${url}" "${destination}" 
				mv "${destination%/*}/${url#*://}" "${destination%/*}"
				url=${url#*://}
				url=${url%%/*}
				rm "${destination%/*}/${url:?}" -R 
			fi
		;;
		# local download only
		ssh)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			offset=$(echo "$_source" | cut -d "/" -f1)

            # getSSH ${host} ${destination} 
            # 

			ssh "${host}" "tar cf - /${_source}/" | pv --timer --rate | tar xf - -C "${destination}/"
			mv "${destination}/${_source}" "${destination}/__temp"
			rm "${destination:?}/${offset:?}" -R
			# move would try to replace existing folders, and throw errors
			cp "${destination}/__temp/*" "${destination}" -Rp
			rm "${destination}/__temp" -R
		;;
		rsync|file|*)
			if [[ -z ${destination} ]]
			then
				echo "$(getRSYNC "$*")"
			else
				#echo "$@" > "${SCRIPT_DIR}/bash/output.log"
	            getRSYNC "$@"  # ${url} ${destination} ${args}
			fi
		;;
		# local file move only
		#file|*)
		#	host=${url#*://}
		#	_source=${host#*:/}
		#	host=${host%:/*}
		#	if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
		#	if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi
		#	tar cf - /${_source} | pv --timer --rate | tar xf - -C ${destination}/
		#	mv ${destination}/${_source} ${destination}/__temp
		#	offset=$(echo "$_source" | cut -d "/" -f2)
		#	rm ${destination}/${offset} -R
		#	mv ${destination}/__temp/* ${destination}
		#	rm ${destination}/__temp -R
		#;;
	esac
}


# API_ENTRY		$src	$dst

#if [[ $# -gt 0 ]]
#then
#	mget $1 $2
#fi
