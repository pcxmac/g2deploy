#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    #   INPUTS    
	#   
	#	    package=<bundle_manifest> ... reference to manifest file, tar's all the contents listed in the manifest by -L
    #       install=<bundle_pkg> ... access /bundle/.../<bundle_pkg>, executes script, then installs patchfiles
    #
    #   
    #   BACKEND SPEC: BUNDLES [ BASH-G2DEPLOY ]
    #
    #       

source ./include.sh

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
