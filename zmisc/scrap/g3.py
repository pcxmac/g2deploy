#!/usr/bin/env python3.10

import socket					# IP INFO
from datetime import datetime
import sys						# script args
import subprocess				# shell commands
import mmap						# mapping text files to RAM : https://realpython.com/python-mmap/


currentHost=socket.gethostbyname(socket.gethostname())
now = datetime.now()
currentDate = now.strftime("%d/%m/%Y %H:%M:%S")

commands='/sbin/rc-service rsyncd stop;'
commands+='/sbin/rc-service lighttpd stop;'
commands='/bin/sync;'
commands+='/var/lib/portage/sync-distfiles.sh;'
commands+='/var/lib/portage/sync-snapshots.sh;'
commands+='/var/lib/portage/sync-releases.sh;'
commands+='/usr/bin/emerge --sync --verbose --ask=n;'
commands+='/usr/bin/eix-update;'
commands+='/bin/sed -i "s|   HOST:.*|   HOST: '+currentHost+'|" /etc/rsync/rsyncd.motd;'
commands+='/bin/sed -i "s|   DATE:.*|   DATE: '+currentDate+'|" /etc/rsync/rsyncd.motd;'
commands+='/usr/bin/sleep 30;'
commands+='/bin/sync;'
#commands+='/sbin/rc-service rsyncd start;'
#commands+='/sbin/rc-service lighttpd start;'
#commands+='echo "hello"'

for args in sys.argv:
	match args:
		case "sync":
			subprocess.run(commands, shell=True)
			


# USE CASEs
#
#	UPDATE		update boot records, kernel, package (upgrade) ... provision new zfs snapshot / 
#	UPGRADE		upgrade a dataset/pool, package upgrade only, patch files
#	DEPLOY		deploy a new dataset/pool
#	SYNCFILES	sync portage rsync files
#	PRUNEPKGS	prune redundant binpkgs ... generate log of redundant pkgs, and delete or place them elsewhere, remove entries in Packages, and 
#	PKGBLD		look at all profile-package lists and check against binpkgs to see if updates required ..
#				build new binpkgs ... generate a log of successful builds and failed builds
#	PKGTEST		test build a package in some profile, all possible use cases, generate a log on successful and unsucccessful build versions.
#	INSTALL		use a YAML document to configure a local machine. 

#
# CONCEPTION
#
#	pool/g1@safe (some gentoo install, which serves as the launch vehicle for PKGBUILDS and USB imaging
#	pool/g2@PROFILE (
#	
#	
#	
#	
#	

# REUSABLE FUNCTIONS

# SUB PROCESSES


# MAIN LOOP


