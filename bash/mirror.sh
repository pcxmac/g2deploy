#!/bin/bash

#	ARGS: 	$MIRROR{ release, snapshots, distfiles, repos } [$TYPE = GET METHOD ] [ $PROFILE{ eselect* } | prefix_type (http/rsync...) | ]
#	OUTPUT: [SCORED] [RANDOMIZED] MIRROR URL (file)
#
#	MIRROR:
#			RELEASE		:	echo the URL for the .XZ and .ASC files (URI.xz|.asc)
#			SNAPSHOTS	:	echo the URL for snapshot sync (system initialization) ... (file|rsync://)
#			DISTFILES	:	echo the URL for distfile sync (file|rsync://)
#			REPOS		:	echo the URL for repos sync (file|rsync://)
#
#
#
#
#
#


	profile="$3"
	type="$2"
	mirror="$1"

	release_base_string=""
	serversList="invalid"

	case ${profile} in
		musl*)			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}-hardened/"		;;
		selinux)		release_base_string="releases/amd64/autobuilds/current-stage3-amd64-hardened-${profile}-openrc/";;
		hardened|clang)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}-openrc/"			;;
		gnome|plasma)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"			;;
		openrc|systemd)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}/"				;;
		*/systemd)		release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-${profile#*/}/"		;;
		*)				release_base_string=""																			;;
	esac

	case "${mirror##*/}" in
		bin*|pack*|kernel*|release*|snaps*|dist*|repos*|patch*|meta*)		serversList="$mirror"				;;
		*)															echo "invalid input";exit		;;
	esac

	if [[ ${type} == "file" ]]
	then
		while read -r server
		do
			case ${server%://*} in
				file)
					case "${mirror##*/}" in
						release*)
							if [[ -n "$release_base_string" ]];	then
								locationStr="$release_base_string"
								urlBase="${server#*://}${locationStr}"
								selectStr="${locationStr#*current-*}"
								selectStr="${selectStr%*/}"
								urlCurrent_xz="$(ls $urlBase | grep "$selectStr" | grep ".xz$")"
								urlCurrent_asc="$(ls $urlBase | grep "$selectStr" | grep ".asc$")"
								urlBase="${server}${locationStr}"
								if [[ -n $urlCurrent_xz ]];	then
									printf "${urlBase}${urlCurrent_xz}\n"
									printf "${urlBase}${urlCurrent_asc}\n"
									exit
								fi
							else
								if [[ ${type} == ${server%://*} ]]; then echo "${server}"; exit; fi
							fi
						;;
						bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
							if [[ ${type} == ${server%://*} ]]; then echo "${server}"; exit; fi
						;;
					esac
				;;
			esac
		done < <(cat $serversList | shuf)
	fi

    # {WEB}://
    while read -r server
    do
		if [[ ${type} == "rsync" ]] && [[ ${server%://*} == "rsync" ]]
		then
			case "${mirror##*/}" in
				release*)
					if [[ -z "${release_base_string}" ]]
					then
						echo "${server}"
						exit
					else
						# THIS IS FOR A SPECIFIC REFERENCE, not a general repo sync
						host="${server#*://}"
						tld="${host##*.}"
						tld="${tld%%/*}"
						hostname="${host%${tld}*}${tld}"
						dir=${host##*${tld}}
						dir=${dir#*/}
						dir=${dir%releases/*}
						selectStr="${release_base_string#*current-}"
						selectStr="${selectStr%*/}"
						urlCurrent_xz="$(rsync -n ${hostname}::${dir}${release_base_string} | awk '{print $5}' | sed -e 's/<[^>]*>//g' | grep "$selectStr" | grep ".xz$")"
						urlCurrent_asc="$(rsync -n ${hostname}::${dir}${release_base_string} | awk '{print $5}' | sed -e 's/<[^>]*>//g' | grep "$selectStr" | grep ".asc$")"
						printf "${server%releases/*}${release_base_string}${urlCurrent_xz}\n"
						printf "${server%releases/*}${release_base_string}${urlCurrent_asc}\n"
						exit
					fi
				;;
				bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
					if [[ ${type} == ${server%://*} ]]; then echo "${server}"; exit; fi
				;;
			esac
       	fi
		if [[ ${type} == "http" || ${type} == "ftp" ]] && [[ ${server%://*} == "http" || ${server%://*} == "ftp" ]]
		then
			case "${mirror##*/}" in
				release*)
					locationStr="$release_base_string"
					urlBase="$server/$locationStr"
					selectStr="${locationStr#*current-*}"
					selectStr="${selectStr%*/}"
					echo "${selectStr} | ${urlBase} | ${locationStr}"

					# filter for curl content, and grep'ing through mangled URLs, ie last few characters are missing or distorted
					urlCurrent="$(curl -s $urlBase --silent | grep "$selectStr" | sed -e 's/<[^>]*>//g' | grep '^stage3-')"
					urlCurrent="$(echo $urlCurrent | awk '{print $1}' | head -n 1 )"
					urlCurrent="${urlCurrent%.t*}"

					if [[ "$release_base_string" != "invalid" ]]; then
						if [[ -n $urlCurrent ]];	then	
							printf "${urlBase}${urlCurrent}.tar.xz\n"
							printf "${urlBase}${urlCurrent}.tar.xz.asc\n"
							exit
						fi
					fi
				;;
				bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
					if [[ ${type} == ${server%://*} ]]; then echo "${server}"; exit; fi
				;;
			esac
		fi
	done < <(cat $serversList | shuf)
