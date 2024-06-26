#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh
pkgARCH="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/arch")"

# DISTRO = version 17.0/1 ... alpha ... etc...
pkgDISTRO=""
#echo "$pkgARCH"


[[ ${pkgARCH}=="*" || -z ${pkgARCH} ]] && { pkgARCH="$(getG2Profile / --arch)"; };

#echo "$pkgARCH"

	profile="${3}"				# parameter 3 can be null, and is handled subsequently.
	type="${2:?}"
	mirror="${1:?}"

	release_base_string=""
	serversList="invalid"

	case ${profile,,} in
		musl*)			release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-${profile}-hardened/"
		;;
		selinux)		release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-hardened-${profile}-openrc/"
		;;
		hardened|clang)	release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-${profile}-openrc/"
		;;
		gnome|plasma)	release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-desktop-openrc/"
		;;
		openrc|systemd)	release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-${profile}/"
		;;
		*/systemd)		release_base_string="/${pkgARCH}/autobuilds/current-stage3-${pkgARCH}-desktop-${profile#*/}/"
		;;
		*)				release_base_string=""


		# merged usr is default

		#	openrc				(split usr/merged usr)
		#		hardened
		#			musl
		#			nomultilib
		#			selinux
		#				nomultilib
		#		desktop
		#		x32
		#		llvm
		#			musl
		#		nomultilib
		#	
		#	systemd				(split usr/merged usr)
		#		llvm			(split usr/merged usr)
		#		desktop			(split usr/merged usr)
		#		hardened
		#		nomultilib		(split usr/merged usr)
		#		x32				(split usr/merged usr)
		#
		#
		#
		#
		#	musl-llvm
		#	musl
		#	musl-hardened

		#	openrc
		#	desktop-openrc
		#	hardened-openrc
		#	openrc-splitusr
		#	nomultilib-openrc
		#	hardened-selinux-openrc
		#	hardened-nomultilib-openrc
		#	hardened-nomultilib-selinux-openrc
		#	x32-openrc
		#	llvm-openrc

		#	systemd
		#	systemd-mergedusr
		#	llvm-systemd
		#	llvm-systemd-mergedusr
		#	desktop-systemd
		#	desktop-systemd-mergedusr
		#	hardened-systemd
		#	nomultilib-systemd
		#	nomultilib-systemd-mergedusr
		#	x32-systemd
		#	x32-systemd-mergedusr

		#	(no stage3)-livegui-amd64
		#	(no stage3)-admincd-amd64
		#	(no stage3)-install-amd64-minimal
		;;
	esac

	case "${mirror##*/}" in
		bin*|pack*|kernel*|release*|snaps*|dist*|repos*|patch*|meta*)		serversList="${mirror}"
		;;
		*)																	echo "invalid input";
																			exit
		;;
	esac

	if [[ ${type} == "file" ]]
	then
		while read -r server
		do
			case ${server%://*} in
				file)
					case "${mirror##*/}" in
						release*)
							if [[ -n "${release_base_string}" ]];	then
								locationStr="${release_base_string}"
								urlBase="${server#*://}${locationStr}"
								selectStr="${locationStr#*current-*}"
								selectStr="${selectStr%*/}"
								#echo "url base = ${urlBase}"
								# ... sort and head get rid of older stale links inside current directory
								urlCurrent_xz="$(ls ${urlBase} | grep "${selectStr}" | sort -r | grep ".xz$" | head -n 1)"
								urlCurrent_asc="$(ls ${urlBase} | grep "${selectStr}" | sort -r | grep ".asc$" | head -n 1)"
								urlBase="${server}${locationStr}"
								if [[ -n $urlCurrent_xz ]];	then
									printf "${urlBase}${urlCurrent_xz}\n"
									printf "${urlBase}${urlCurrent_asc}\n"
									exit
								fi
							else
								if [[ ${type} == "${server%://*}" ]]; then echo "${server}"; exit; fi
							fi
						;;
						bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
							if [[ ${type} == "${server%://*}" ]]; then echo "${server}"; exit; fi
						;;
					esac
				;;
			esac
		done < <(cat ${serversList} | shuf)
	fi

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
						host="${server#*://}"
						tld="${host##*.}"
						tld="${tld%%/*}"
						hostname="${host%${tld}*}${tld}"
						dir="${host##*${tld}}"
						dir="${dir#*/}"
						dir="${dir%releases/*}"
						selectStr="${release_base_string#*current-}"
						selectStr="${selectStr%*/}"
						# check for host ... sort and head get rid of older stale links inside current directory
						[[ -z "$(isHostUp ${hostname} 873)" ]] && { exit; }
						urlCurrent_xz="$(rsync -n ${hostname}::${dir}${release_base_string} | awk '{print $5}' | sed -e 's/<[^>]*>//g' | grep "${selectStr}" | sort -r | grep ".xz$" | head -n 1 )"
						urlCurrent_asc="$(rsync -n ${hostname}::${dir}${release_base_string} | awk '{print $5}' | sed -e 's/<[^>]*>//g' | grep "${selectStr}" | sort -r | grep ".asc$" | head -n 1 )"
						printf "${server%releases/*}${release_base_string}${urlCurrent_xz}\n"
						printf "${server%releases/*}${release_base_string}${urlCurrent_asc}\n"
						exit
					fi
				;;
				bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
					if [[ ${type} == "${server%://*}" ]]; then echo "${server}"; exit; fi
				;;
			esac
       	fi
		if [[ ${server%://*} == "${type}" ]]
		then
			case "${mirror##*/}" in
				release*)
					locationStr="${release_base_string}"
					urlBase="${server}${locationStr}"
					selectStr="${locationStr#*current-*}"
					selectStr="${selectStr%*/}"
					# check for host
					hostname="$(getHostName ${urlBase})"

					# eselect profile is getting punked, wtf bro ! --- attempted to delete extraneous folders in portage-patchfiles, profile and saved config
					#echo "$hostname $selectStr $urlBase $locationStr $urlCurrent"
					# ... sort and head get rid of older stale links inside current directory
					[[ -z "$(isHostUp ${hostname} '80')" && -z "$(isHostUp ${hostname} '443')" ]] && { exit; };
					if [[ ${type} == "http" ]];then urlCurrent="$(curl -s ${urlBase} --silent | grep "${selectStr}" | sed -e 's/<[^>]*>//g' | grep '^stage3-' | sort -r)"; fi
					if [[ ${type} == "ftp" ]];then urlCurrent="$(curl -s ${urlBase} --silent --list-only | grep "${selectStr}" | sed -e 's/<[^>]*>//g' | grep '^stage3-' | sort -r)"; fi

					#echo "$urlCurrent"
					urlCurrent="$(echo ${urlCurrent} | awk '{print $1}' | head -n 1 )"
					urlCurrent="${urlCurrent%.t*}"

					if [[ "${release_base_string}" != "invalid" ]]; then
						if [[ -n ${urlCurrent} ]];	then	
							printf "${urlBase}${urlCurrent}.tar.xz\n"
							printf "${urlBase}${urlCurrent}.tar.xz.asc\n"
							exit
						fi
					fi
				;;
				bin*|pack*|kernel*|dist*|repos*|snaps*|patch*|meta*)
					if [[ ${type} == "${server%://*}" ]]; then echo "${server}"; exit; fi
				;;
			esac
		fi
	done < <(cat ${serversList} | shuf)
