#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"


# ARGS = work=$

    # INPUTS    
	#
	#		profile=jupiter.hypokrites.me
	#		work=local/remote zfs://root@localhost:/pool/set
	#		bootpart=/dev/sdYX
	#	
	#		buildenv	#	examin a work#space/bootenv, save to a profile. 
	#		buildout	#	takes a profile patch, a work#space, patch it, on a clone.

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

#       store values in portage/profiles/[domain]/[hostname]
#       ex. hypokrites.net/dom0 ... subdomains are attached to the hostname
#       ex. happy.printer = hostname, hypokrites.net = domain
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


            ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            profile=*)


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
