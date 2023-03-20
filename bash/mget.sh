#!/bin/bash

#	1 source/tree/leaf		-->	destination/D/			... copy leaf in to D/
#	2 source/tree/branch/	--> destination/D/			... copy contents of branch in to D/
#	3 source/tree/leaf	 	--> destination/D			... copy leaf as D

#	1> source/tree/branch/*	-->	destination/D/			<INVALID!>, don't allow wildcards right now, it causes variability in command line args --unstable!
#	2> source/tree/branch/ 	--> destination/D			<RE-ASSIGN>, add / to end of D , ergo D/
#	3> source/tree/branch/*	-->	destination/D			<INVALID>, this must break.		--filtered to read branch/ destination/D { invalid, 2> }
#	\						--> destination/D/*			<INVALID>, this must break.		--filtered to read \ destination/D/ {1;2}

#	summary : 1,2,3 work, 2> reverts to 2, all other cases are filtered by sed 's|g' -- no returns, or breaks, every case should work.

#	all copies are recursive, and attempt to preserve permissions

#	working ...
#	file 		(display total size, destination, source, progress)		*RSYNC
#	rsync		""														*RSYNC
#	ssh			""														*SCP
#	http		""														*WGET
#	(s/t)ftp(s)	""														*WGET	(only supports ()ftp currently)

#	to be ...	(may require non standard services)
#	net			""					net://host:9000/	./file			*NETCAT/SOCAT/(bash+/dev/tcp)	| 	requires netcat on host
#	nfs			""					nfs://user@host/share/file			*nfsv4							|	
#	smb			""					smb://user@host/directory/file		*samba							|	
#	serial		""					serial://device:params/	./file		*kermit							|	serial transfer

# 	dependencies : [wget]	[scp]	[sleep]	[]	[]	[]	[]

#	support for stdin & stdout
#	
#	ex.		cat ./file | mget . ${destination}
#	ex.		mget ${url} | ./destination
#	ex.		mget <(cat file) ./destination
#	
#	limitations, only supports local writes, or "getting"
#	see mput, for standardized "sending"
#
#	supports timingout 							
#	supports extensible options (like rsync)	(*)
#	supports testing w/ test_map.xml file		(-t)

function dirCount()
{
	_url="${1:?}"
	_proto="${_url%://*}"
	_url="${_url#${_proto}://*}"
	_host="${_url%%/*}"
	_url="${_url#*${_host}}"
	_url="$(printf $_url | sed 's/\/$//' | sed 's/^\///')"
	_count=0
	while [[ ${_url} != ${_url#*/} ]]
	do
		((_count++))
		_url="${_url#*/}"
	done
	printf '%s\n' $_count
}


function getSSH()
{
	echo "getSSH"
}

function getRSYNC()
{
	local host="${*:?}"
	local waiting=1
	local rCode=""
	local pause=60
	local uri=""
	#  there should always be a destination for rsync, this method does not support streaming
	local destination="${2:?}"			

	host="${host#*://}"
	host="${host%%/*}"

	while [[ "${waiting}" == 1 && -n "${host}" ]]
	do
		rCode="$(timeout 10 rsync -n "${host}":: 2>&1 | \grep 'Connection refused')"
        if [[ -z "${rCode}" ]]
		then
			if [[ -z "${destination}" ]]
			then
				uri="${1:?}"
				scp "${uri#*rsync://}" /dev/stdout
			else
				if [[ -n ${host} ]]
				then
					rsync -ar --links --no-motd --human-readable --info=progress2 --rsync-path="sudo rsync" $*
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

	if [[ -z ${host} ]]
	then
			rsync -ar --links --no-motd --info=progress2 --human-readable --rsync-path="sudo rsync" "${@#*rsync://}" 
	fi
}

function getHTTP() 	#SOURCE	#DESTINATION #WGET ARGS
{
	# empty if streaming/serial output requested
	local destination="${2}"		
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
				wget -nH --cut-dirs=$(dirCount ${url}) -O - --reject "index.*" -q --show-progress --no-parent "${url}" 2>/dev/null
			else
				wget -nH --cut-dirs=$(dirCount ${url}) -r --reject "index.*" -q --show-progress --no-parent "${url}" -P "${destination%/*}" 2>&1 | pv --progress 1>/dev/null
			fi
			waiting=0
		else
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done
}

function getFTP()
{
	local destination="${2:?}"
	local url="${1:?}"
	local waiting=1
	local ftpCode=""
	local pause=60

	#echo "cutdirs = $(dirCount $url)" 2>&1

	while [[ ${waiting} == 1 ]]
	do
		ftpCode="$(wget -NS --spider "${url%\**}" 2>&1 | \grep "No such file *."  | awk '{print $2}')"
		if [[ -z "${ftpCode}" ]]
		then
			if [[ -z ${destination} ]]
			then
				wget -nH --cut-dirs=$(dirCount ${url}) -O - --reject "index.*" -q --show-progress  --no-parent "${url}" 2>/dev/null
			else
				wget -nH --cut-dirs=$(dirCount ${url}) -r --reject "index.*" -q --show-progress  --no-parent "${url}" -P "${destination}" 2>&1 | pv --progress 1>/dev/null
			fi
			waiting=0
		else
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done

}

function mget()
{
	# destination_FS, can be empty, stream output (ie no output file specified)
	local offset
	local host
	local _source

	# filter out invalid use cases
	local url="$(printf '%s\n' "${1:?}" | sed 's/\*//g')"
	local destination="$(printf '%s\n' "${2}" | sed 's/\*//g')"

	[[ -n "$(printf "${url}" | grep '/$')" && -z "$(printf "${destination}" | grep '/$')" ]] && { destination="${destination}/"; } 

	# mget types
	case ${url%://*} in

		ftp*)
			if [[ -z ${destination} ]]
			then
				echo "$(getFTP ${url})"
			else
				echo "$(getFTP ${url})"
				getFTP "${url}" "${destination}"		
			fi
		;;
		http*)
			if [[ -z ${destination} ]]
			then
				echo "$(getHTTP ${url})"
			else
				echo "$(getHTTP ${url})"
				getHTTP "${url}" "${destination}" 
			fi
		;;

		# NEEDS A LOT OF WORK !
		ssh)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			offset=$(echo "$_source" | cut -d "/" -f1)
			ssh "${host}" "tar cf - /${_source}/" | pv --timer --rate | tar xf - -C "${destination}/"
			mv ${destination}/${_source} ${destination}/__temp
			rm ${destination:?}/${offset:?} -R
			cp ${destination}/__temp/* ${destination} -Rp
			rm ${destination}/__temp -R
		;;

		# Pending review .. and a test schema
		rsync|file|*)
			if [[ -z ${destination} ]]
			then
				echo "$(getRSYNC "$*")"
			else
				#echo "$@" >> ${SCRIPT_DIR}/bash/output.log
				#echo $@
	            getRSYNC $*  # ${url} ${destination} ${args}
			fi
		;;
	esac
}