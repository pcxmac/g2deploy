#!/bin/bash

#zfs snapshot wSys/portage@$(date --iso-8601)
rsync -avP rsync://mirror.rackspace.com/gentoo/* ./
#rsync -avP --delete-before rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/releases/amd64 ./releases/




#rsync -avP rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/snapshots ./snapshots
#rsync -avP rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/experimental ./experimental
#rsync -avP rsync://mirror.csclub.uwaterloo.ca/gentoo-distfiles/ ./
