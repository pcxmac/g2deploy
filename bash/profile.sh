#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    # INPUTS    
	#
	#		profile=jupiter.hypokrites.me
	#		work=local/remote zfs://root@localhost:/pool/set
    #       work={config_file w/ multiple pools/sets/directories to snap from} (0.4>)
	#		bootpart=/dev/sdYX
    #       keymat=/root/location/of/key (0.2+)
	#	
	#		buildenv	#	examin a work#space/bootenv, save to a profile. 
	#		buildout	#	takes a profile patch, a work#space, patch it, on a clone.
    #
    # BACKEND SPEC: <PROFILER> [ BASH-G2DEPLOY ]
    #
    #       0.1 - manual/local profile assertion, no privacy|encryption
    #       0.2 - local assertion, encrypted 
    #       0.3 - local/remote assertion, encrypted
    #       0.4 - provision for more sophisticated encryption
    #       0.5 - configs (scripts for targeting validated locations)
    #       0.6 - multiple archives per machine
    #
    #       /profile/tld/domain/machine.sig
    #       /profile/...hidden.../private_master_key
    #       /profile/public_master_key
    #       /machine_root/.../private_key
    #       /machine_root/.../public_key
    #       compress profile locally (.tar.lz4)
    #       encrypt profile w. public_key (PKI) (user privacy)
    #       sign encrypted profile (profile.crypt) + public_key with public_master_key (user-backend authentication)
    #           if using a rolling key, user must provide current key,original key, signed with the public_key to the backend server,
    #           so, upon future pull, the option for providing *keymat is available.
    #       ... on the user side, the key can be held in an initramfs, which might pull a machine profile, or in a key cache for
    #           generating the NON-generic image. it is important to remember, user data as well as package info is stored.
    #           the profiles are as much a userspace snapshot as well as a backup of user-data (/home/...)
    #       upon receipt, the backend can unsign the package to reveal the client's public key, this key can be catalogged for future 
    #           reference/authentication. This serves as a secure token for uploading the data elsewhere. 
    #       
    # BACKEND SPEC: <CA_SPEC> [ PYTHON-NEXUS ]
    #       
    #       provide functions for BACKEND processes/processing, (PROFILER 0.2=>)
    #       

source ./include.sh

###################################################################################################################################

#   GRAB:
#       profile         get profile from chroot.
#       /etc/           tar cfvz etc.tar.gz (pulls in network configuration) && (rc.conf/sysctl)
#       <services>      rc-update 1> [hostname].services | manually reset these
#       zfs-keys        (tar cfvz -List , develop list from zfs_keys list)
#       pkg selector    (take globals, diff from profile generated, output to [hostname].pkgs )
#       users			tar cfvz home.tar.gz ; root.tar.gz
#		--profile		grab profile.
#
#		~/
#			profile.txt
#			etc.tar.gz
#			config.services
#			zfs_keys.tar.gz
#			config.pkgs
#			users.tar.gz
#           		
	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f system
	export -f services
	export -f install_modules

########################################## DEFINES

    base_URL="file:///var/lib/portage/profile"

    for x in $@
    do
        case "${x}" in
            work=*)
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"
            ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            bootpart=*)
               efi_part=${x#*=}
             ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            profile=*)      
                proper_name=${x#*=}
                if [[ -d ${base_URL}${proper_name} ]];then echo "profile present, exiting."; exit; fi
                
            ;;
        esac
    done

########################################### SHIGOTO

    for x in $@
    do
        case "${x}" in
            buildout=*)
                # GET PROFILE OF SAVED_ENV (profile/tld/domain/sub-pro)
                # SNAPSHOT PROPER PROFILE_TYPE ACCORDING TO JULIANDAY, (WORK*)
                # SET WORKENV TO CLONE OF PROPER PROFILE_TYPE 
                # 
                # 
                # REQUIRES DOM0_CA_SERVICE: [DECRYPT_PROFILE]

            ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            buildenv=*)
                # WORK* , get profile, and working directory
                # extract the goods (LIST, from root)
                # profile -> profile
                # service chain (generate a script called services.sh). for every service, add a line to (supports OPENRC ONLY right now)
                # capture ZFS keys, reference the keylocation, then lookinside the root for that location, save to zfs.key
                # get the public key from /profile/public/key and sign the archive (subdomain folder to tar.xfvz)
                #
                #
                #
                #
                #

            ;;
        esac
    done
