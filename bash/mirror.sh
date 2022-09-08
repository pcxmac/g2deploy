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
	root="$(pwd)"
	mirror_type="invalid"
	release_base_string="invalid"
	serversList="invalid"

	case ${profile} in
		"selinux")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-hardened-selinux-openrc/"
		;;
		"clang")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-clang-openrc/"
		;;		
		"gnome")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
		;;
		"plasma")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
		;;
		"openrc")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-openrc/"
		;;
		"hardened")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/"
		;;
		"systemd")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-systemd/"
		;;
		"gnome/systemd")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
		;;
		"plasma/systemd")
			release_base_string="releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
		;;
#		"*")
#			release_base_string="not a release search"
#		;;
#		*)
#			#release_base_string=""
#		;;
	esac


	case "${type##*/}" in
		release*|snaps*|dist*|repos*)
			serversList="$type"
		;;
		*)
			echo "invalid input"
			exit
		;;
	esac
	#FILE:///
    while read -r server
    do
    	case ${server%://*} in
			"file")
				case "${type##*/}" in
					release*)
						if [[ "$release_base_string" != "invalid" ]]
						then
						locationStr="$release_base_string"
						urlBase="${server#*://}${locationStr}"

						selectStr="${locationStr#*current-*}"
						selectStr="${selectStr%*/}"

#						echo $urlBase 
#						ls $urlBase | grep $selectStr 

						urlCurrent_xz="$(ls $urlBase | grep "$selectStr" | grep ".xz$")"
						urlCurrent_asc="$(ls $urlBase | grep "$selectStr" | grep ".asc$")"

						if [[ -n $urlCurrent_xz ]] 
    	                then
							echo "${urlBase}${urlCurrent_xz}"
							echo "${urlBase}${urlCurrent_asc}"
							exit
						fi

					fi
					;;
					dist*)
						if [[ -d ${server#*://} ]]
						then
							echo $server
							exit
						fi
					;;
					repos*)
						if [[ -d ${server#*://} ]]
						then
							echo $server
							exit
						fi
					;;
					snaps*)
						if [[ -d ${server#*://} ]]
						then
							echo $server
							exit
						fi
					;;
				esac
			;;
		esac
    done < <(cat $serversList | shuf)


    # {WEB}://
    while read -r server
    do
    	case ${server%://*} in
            "rsync" | "http" | "ftp")
				case "${type##*/}" in
            	release*)
					if [[ "$release_base_string" != "invalid" ]]
                    then

					locationStr="$release_base_string"
					urlBase="$server/$locationStr"

					selectStr="${locationStr#*current-*}"
					selectStr="${selectStr%*/}"

					urlCurrent="$(curl -s $urlBase | grep "$selectStr" | sed -e 's/<[^>]*>//g' | grep '^stage3-' | awk '{print $1}' | head -n 1 )"
					urlCurrent="${urlCurrent%.t*}"
					
					if [[ -n $urlCurrent ]] 
                    then
						echo "${urlBase}${urlCurrent}.tar.xz"
						echo "${urlBase}${urlCurrent}.tar.xz.asc"
	                    exit
					fi
                fi
				;;
                dist*)

					if [[ ${server#*://} ]] 
                    then
                		echo $server
						exit
                    fi
                ;;
                repos*)
                    
					if [[ ${server#*://} ]] 
                    then
                       echo $server
                       exit
                    fi
                ;;
                snaps*)
                    
					if [[ ${server#*://} ]]
                    then
                       echo $server
                       exit
                    fi
                ;;
            esac
		;;
    esac
done < <(cat $serversList | shuf)
