#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    #           meta package manager (MPM)
    #   INPUTS 
	#   
	#	    package=<bundle_manifest> ... reference to manifest file, tar's all the contents listed in the manifest by -L
    #       install=<bundle_pkg> ... access /bundle/.../<bundle_pkg>, executes script, then installs patchfiles
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
			newLine="${PREFIX}"
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
						#if [[ ${match} == "" ]];then echo "adding ${argS}"; fi
						newLine="${newLine} ${arg}"
					done
					echo "sed -i "/${PREFIX}/c ${newLine}" ${package_use}"
					#sed -i "/$PREFIX/c $newLine" ${package_use}
					sed -i "//c $" ${package_use}

				fi
			else
				#echo "${line}"
				echo "${line}" >> ${package_use}
			fi

		done < <(cat ${fileHandle})
}

function installPackages() {
sleep 1

}

function modifyModules() {
sleep 1

}

function addServices() {
sleep 1

}

function patchUp() {
sleep 1

}



###################################################################################################################################

    #   GRAB:
    #
    #       tar LIST grab of all /var/.. ; /etc/... ; /opt/ or what have yee
    #       list of packages
    #
    #
    #
    #
    #

	modifyUsesFlags "/var/lib/portage/meta/libvirt/uses" "/etc/portage/package.use"

	for x in $@
	do
		case "${x}" in
			install=*)
				manifest_file=${x#*=}
			;;
			work=*)
				root_directory=${x#*=}
			;;
		esac
	done


	for x in $@
	do
		case "${x}" in
			package=*)
				bundle_location=${x#*=}
			;;
			work=*)
				=${x#*=}
			;;
		esac
	done




