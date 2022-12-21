#!/bin/bash

# this command pulls one key value out of the host.cfg, in same folder

# ARG LIST SYNTAX : host.sh pkgserver host; yields = (ex.) 10.1.0.1


config_file="./host.cfg"
server=$1
key=$2

function scanConfig() {

	header=$1
	key=$2

	# header has pattern \[[a-z]\]

	for line in "$(cat ${config_file})"
	do
		


	done

}


case ${server} in
	pkgserver)
				case ${key} in
					host)
						line=scanConfig ${server} ${key}
						;;
					*)	exit
						;;
				esac
				;;
	buildserver)
				case ${key} in
					host)
						line=scanConfig ${server} ${key}
						;;
					*)	exit
						;;
				esac
				;;
	*)
				exit
				;;
esac

value=${line#*=}
echo ${value}
