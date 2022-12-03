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
	#		buildenv	#	examin a work#space, save to a profile. 
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
#
#		WORK=		...working directory
#		PACKAGE=	...
#		INSTALL=


	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f system
	export -f services
	export -f install_modules

    for x in $@
    do
        case "${x}" in
            work=*)
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"
            ;;
        esac
    done

	if [[ -z ${directory }]]l then exit; fi

	destination="/var/portage/profiles/"

    for x in $@
    do
        case "${x}" in
            package=*)
				profile=getG2Profile ${directory}
				hostname=$(chroot ${directory} /bin/bash -c "hostname")
				domain=$(chroot ${directory} /bin/bash -c "dnsdomainname")
				destination="${destination}/${domain}/${hostname}"
				echo $destination $dataset $domain $hostname $profile

            ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            install=*)

            ;;
        esac
    done