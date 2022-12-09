#!/bin/bash

#	ARGS: 	$TYPE{ release, snapshots, distfiles, repos } [ $PROFILE{ eselect* } | prefix_type (http/rsync...) ]
#	OUTPUT: [SCORED] [RANDOMIZED] MIRROR URL (file)
#
#	TYPE:
#			RELEASE		:	echo the URL for the .XZ and .ASC files (URI.xz|.asc)
#			SNAPSHOTS	:	echo the URL for snapshot sync (system initialization) ... (file|rsync://)
#			DISTFILES	:	echo the URL for distfile sync (file|rsync://)
#			REPOS		:	echo the URL for repos sync (file|rsync://)

	profile="$2"
	type="$1"
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

	case "${type##*/}" in
		bin*|pack*|kernel*|release*|snaps*|dist*|repos*|patch*|meta*)		serversList="$type"				;;
		*)															echo "invalid input";exit		;;
	esac

	
    while read -r server
    do
    	case ${server%://*} in
			file)
				case "${type##*/}" in
					release*)
						if [[ "$release_base_string" != "invalid" ]];	then
							locationStr="$release_base_string"
							echo $locationStr
							urlBase="${server#*://}${locationStr}"
							selectStr="${locationStr#*current-*}"
							selectStr="${selectStr%*/}"
							urlCurrent_xz="$(ls $urlBase | grep "$selectStr" | grep ".xz$")"
							urlCurrent_asc="$(ls $urlBase | grep "$selectStr" | grep ".asc$")"
							urlBase="${server}${locationStr}"
							if [[ -n $urlCurrent_xz ]];	then
								echo "${urlBase}${urlCurrent_xz}"
								echo "${urlBase}${urlCurrent_asc}"
								exit
							fi
						else
							if [[ ${profile} == ${server%://*} ]]; then echo "${server}"; exit; fi
						fi
					;;
					bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
						if [[ ${profile} == ${server%://*} ]]; then echo "${server}"; exit; fi
					;;
				esac
			;;
		esac
    done < <(cat $serversList | shuf)

    # {WEB}://
    while read -r server
    do
    	case ${server%://*} in
			rsync)
				case "${type##*/}" in
            		release*)
						#echo "$release_base_string"
						if [[ -z $release_base_string ]];	then	echo "${server}";	exit;	fi
					;;
					bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
						if [[ ${profile} == ${server%://*} ]]; then echo "${server}"; exit; fi
					;;
				esac
			;;
          	http*|ftp)
				case "${type##*/}" in
            		release*)
						locationStr="$release_base_string"
						urlBase="$server/$locationStr"
						selectStr="${locationStr#*current-*}"
						selectStr="${selectStr%*/}"
						# filter for curl content, and grep'ing through mangled URLs, ie last few characters are missing or distorted
						urlCurrent="$(curl -s $urlBase --silent | grep "$selectStr" | sed -e 's/<[^>]*>//g' | grep '^stage3-')"
						urlCurrent="$(echo $urlCurrent | awk '{print $1}' | head -n 1 )"
						urlCurrent="${urlCurrent%.t*}"
						if [[ "$release_base_string" != "invalid" ]]; then
							if [[ -n $urlCurrent ]];	then	
								echo "${urlBase}${urlCurrent}.tar.xz"
								echo "${urlBase}${urlCurrent}.tar.xz.asc"
								exit
							fi
						fi
					;;
                	bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
						if [[ ${profile} == ${server%://*} ]]; then echo "${server}"; exit; fi
                	;;
	            esac
			;;
    	esac
	done < <(cat $serversList | shuf)
