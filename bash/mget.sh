#
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

function getRSYNC()
{
	local host=$@
	local waiting=1
	local rCode=""
	local pause=60

	host=${host#*://}
	host=${host%%/*}

	while [[ ${waiting} == 1 ]]
	do
		rCode="$(timeout 10 rsync -n ${host}:: 2>&1 | \grep 'Connection refused')"
        if [[ -z "${rCode}" ]]
		then
			rsync -a --no-motd --info=progress2 $@ 
			waiting=0
		else
			waiting=1
			sleep ${pause}
			pause=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done
	echo $rCode
}


function getHTTP() 	#SOURCE	#DESTINATION #WGET ARGS
{
	local destination=$2
	local url=$1
	local waiting=1
	local httpCode=""
	local pause=60

	while [[ ${waiting} == 1 ]]
	do
		httpCode="$(wget -NS --spider ${url%\**} 2>&1 | \grep "HTTP/" | awk '{print $2}' | \grep '200' | uniq)"
		if [[ "${httpCode}" == "200" ]]
		then
			wget -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination%/*} --show-progress
			waiting=0
		else
			#ipCheck="$(ping ${url} -c 3 | grep "0 received")"
			#if [[ -n ${ipCheck} ]];then echo "."; fi
			waiting=1
			sleep ${pause}
			sleep=$((pause-1))
			if [[ ${pause} == 0 ]]; then waiting=0; fi
		fi
	done
	echo $httpCode
}

function getFTP()
{
	local destination=$2
	local url=$1
	local waiting=1
	local ftpCode=""
	local pause=60

	while [[ ${waiting} == 1 ]]
	do
		ftpCode="$(wget -NS --spider ${url%\**} 2>&1 | \grep "No such file *."  | awk '{print $2}')"
		if [[ -z "${ftpCode}" ]]
		then
			wget -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination} --show-progress
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
	echo $ftpCode
}




function mget()
{

	#local url="$(echo "$1" | tr -d '*')"			# source_URL
	local destination=$2	# destination_FS
	local args=$3
	local offset
	local host
	local _source
	local url=$1 # source_URL


	case ${url%://*} in
		# local rsync only
		rsync)
            getRSYNC $@  # ${url} ${destination} ${args}
			#rsync -av ${args} ${url} ${destination}
		;;
		ftp*)
			getFTP ${url} ${destination} 
			#wget ${args} -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination}	--show-progress
			mv ${destination}/${url#*://} ${destination}/
			url=${url#*://}
			url=${url%%/*}
			rm ${destination}/${url} -R
		;;
		http*)
			getHTTP ${url} ${destination} 
			#wget ${args} -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination%/*}	--show-progress

			mv ${destination%/*}/${url#*://} ${destination%/*}
			url=${url#*://}
			url=${url%%/*}
			rm ${destination%/*}/${url} -R 
		;;
		# local download only
		ssh)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			offset=$(echo "$_source" | cut -d "/" -f1)

            # getSSH ${host} ${destination} 
            # 

			ssh ${host} "tar cf - /${_source}/" | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${_source} ${destination}/__temp
			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R

		;;
		# local file move only
		file|*)
			host=${url#*://}
			_source=${host#*:/}
			host=${host%:/*}
			if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
			if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi
			tar cf - /${_source} | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${_source} ${destination}/__temp
			offset=$(echo "$_source" | cut -d "/" -f2)
			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;
	esac
}
