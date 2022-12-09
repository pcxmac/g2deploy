#!/bin/bash
#[ $# -ge 1 -a -f "$1" ] && input="$1" || input="-"

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    #           meta package manager (MPM)
    #   INPUTS 
	#   
	#	    package=<bundle_manifest> ... reference to manifest file, tar's all the contents listed in the manifest by -L
    #       install=<bundle_pkg> ... access /bundle/.../<bundle_pkg>, executes script, then installs patchfiles
	#		
    #       0.1 - local only / only deploy
	#		0.2 - build local packages
    #       0.3 - remote + local package accesss (mirror via bundle.mirrors)
    #       0.4 - 
    #
    #       work=pool/dataset ... to chroot to.
    #   
    #   BACKEND SPEC: BUNDLES [ BASH-G2DEPLOY ]
    #
    #       

source ./include.sh

####################################### INSTALL PACKAGE 0.1

function modifyUsesFlags() {

	local fileHandle=$1
	local package_use=$2

	while read line; do
			PREFIX=${line%%[[:space:]]*}
			RFIX="${PREFIX%/*}\/${PREFIX#*/}"
			newLine="${RFIX}"
			ARGS=${line#*[[:space:]]}
			DESTINATION=$(cat ${package_use} | \grep ${PREFIX} ${package_use})
			D_ARGS=${DESTINATION#*[[:space:]]}

			if [[ -n ${DESTINATION} ]]
			then
				if [[ -n $line ]]
				then

					for argS in ${ARGS}
					do
						arg=""
						match=""
						for argD in ${D_ARGS}
						do
							if [[ ${argD} == ${argS} ]];then arg=${argD}; fi
							if [[ ${argD} != ${argS} ]] || [[ *"${argD} " == *"${argS} " ]];then arg=${argS}; fi
						done
						newLine="${newLine} ${arg}"
					done
					#sed -n "/${RFIX}/c ${newLine}" ${package_use}
					sed -i "/${RFIX}/c ${newLine}" ${package_use}
				fi
			fi

		done < <(cat ${fileHandle})
}

function installPackages() {
	sh $1
}

function installPatches() {
	sh $1
}

function addServices() {
	sh $1
}

function modifyModules() {
	# looking for modules="..."

	# strip modules/args

	local modSource=$1
	local modDestination=$2

	local args="$(cat ${modSource} | \grep "^modules=")"
	args=${args#*modules=}
	args="$(echo ${args} | tr -d '"')"

	prefix="modules="

	local dontInsert=""

	# parse through existing modules= statements, cycle through every arg, ensure they are present, 

	echo "args = ${args}"

	for arg in ${args}
	do
		checkLines="$(cat ${modDestination} | \grep "^modules=")"
		echo "checkLines = ${checkLines}"

		for checkLine in ${checkLines}
		do 
			lResult="$(echo ${checkLine} | grep ${arg})"
			if [[ -n ${lResult} ]]
			then
				dontInsert="${arg}"
			fi
		done
		if [[ -z ${dontInsert} ]]
		then
			oldArgs="$(echo "${checkLine#*modules=\"}" | tr -d '"')"
			sed -i "/${prefix}\"${oldArgs}\"/c ${prefix}\"${oldArgs} ${arg}\"" ${modDestination}
		fi
	done
}

	#modifyUsesFlags "/var/lib/portage/meta/libvirt/uses" "/etc/portage/package.use"
	#installPackages "/var/lib/portage/meta/libvirt/packages"
	#installPatches "/var/lib/portage/meta/libvirt/patches"
	#modifyModules "/var/lib/portage/meta/libvirt/modules" "/etc/conf.d/modules"

	for x in $@
	do
		case "${x}" in
			install=*)
				source=${x#*=}	# ex. /var/lib/portage/meta/libvirt
				destination=""
			;;
			work=*)
				work=${x#*=}	# ex. /srv/zfs/jupiter/gnome
			;;
		esac
	done

	for x in $@
	do
		case "${x}" in
			package=*)
				destination=${x#*=}
				source=""
			;;
			work=*)
				work=${x#*=}
			;;
		esac
	done

	if [[ -n ${work} ]] 
	then
		mounts ${work}
	else
		echo "no working directory declared"
		exit
	fi




	if [[ -n ${destination} ]]	# install
	then
	#	chroot 	- install packages

	#			- config install

	#			- use flags

	#	chroot	- services

	#			- modules

	#	chroot	- patches


	else						# package
	#	
	#	
	#	
	#	
	#	
	#	
		echo "packaging accomplished manually for now..."

	fi

	clear_mounts ${work}

