#!/bin/bash

#	ARGS: 	$TYPE{ release, snapshots, distfiles, repos } $PROFILE{ eselect* }
#	OUTPUT: [SCORED] [RANDOMIZED] MIRROR URL (file)
#
#	TYPE:
#			RELEASE		:	echo the URL for the .XZ and .ASC files (URI.xz|.asc)
#			SNAPSHOTS	:	echo the URL for snapshot sync (system initialization) ... (file|rsync://)
#			DISTFILES	:	echo the URL for distfile sync (file|rsync://)
#			REPOS		:	echo the URL for repos sync (file|rsync://)

	profile="$2"
	type="$1"
	release_base_string="invalid"
	serversList="invalid"

	case ${profile} in
		musl*)			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}-hardened"		;;
		selinux)		release_base_string="releases/amd64/autobuilds/current-stage3-amd64-hardened-${profile}-openrc/";;
		hardened|clang)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}-openrc/"			;;
		gnome|plasma)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"			;;
		openrc|systemd)	release_base_string="releases/amd64/autobuilds/current-stage3-amd64-${profile}/"				;;
		*/systemd)		release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-${profile#*/}/"		;;
	esac

	case "${type##*/}" in
		bin*|pack*|kernel*|release*|snaps*|dist*|repos*)		serversList="$type"				;;
		*)														echo "invalid input";exit		;;
	esac

	#FILE:///
    while read -r server
    do
    	case ${server%://*} in
			file)
				case "${type##*/}" in
					release*)
						if [[ "$release_base_string" != "invalid" ]];	then
							locationStr="$release_base_string"
							urlBase="${server#*://}${locationStr}"
							selectStr="${locationStr#*current-*}"
							selectStr="${selectStr%*/}"
							urlCurrent_xz="$(ls $urlBase | grep "$selectStr" | grep ".xz$")"
							urlCurrent_asc="$(ls $urlBase | grep "$selectStr" | grep ".asc$")"
							# redefine urlBase for correct URL format, file:/// relative file reference is invalid
							urlBase="${server}${locationStr}"
							if [[ -n $urlCurrent_xz ]];	then
								echo "${urlBase}${urlCurrent_xz}"
								echo "${urlBase}${urlCurrent_asc}"
								exit
							fi
						else
							case ${server%://*} in
								file)
									if [[ -n ${server} ]];	then	echo "${server}";	exit;	fi
								;;
							esac
						fi
					;;
					bin*|pack*|kernel*|dist*|repos*|snaps*)
						if [[ -d ${server#*://} ]];	then			echo ${server};		exit;	fi
					;;
				esac
			;;
		esac
    done < <(cat $serversList | shuf)

    # {WEB}://
    while read -r server
    do
    	case ${server%://*} in
            rsync | http | ftp)
				case "${type##*/}" in
            	release*)
					locationStr="$release_base_string"
					urlBase="$server/$locationStr"
					selectStr="${locationStr#*current-*}"
					selectStr="${selectStr%*/}"
					# filter for curl content, and grep'ing through mangled URLs, ie last few characters are missing or distorted
					urlCurrent="$(curl -s $urlBase | grep "$selectStr" | sed -e 's/<[^>]*>//g' | grep '^stage3-')"
					urlCurrent="$(echo $urlCurrent | awk '{print $1}' | head -n 1 )"
					urlCurrent="${urlCurrent%.t*}"
					if [[ "$release_base_string" != "invalid" ]]; then
						if [[ -n $urlCurrent ]];	then	
							echo "${urlBase}${urlCurrent}.tar.xz"
							echo "${urlBase}${urlCurrent}.tar.xz.asc"
							exit
						fi
					else
						if [[ -n ${server} ]];	then	echo "${server}";	exit;	fi
                	fi
				;;
                bin*|pack*|kernel*|dist*|repos*|snaps*)
					echo "${server}"
					exit
                ;;
            esac
		;;
    esac
done < <(cat $serversList | shuf)
