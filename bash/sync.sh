#!/bin/bash

# backend data-server synchronization (no arguments) 
#
#   /var/lib/portage
#       /snapshots
#       /releases
#       /distfiles
#       /repos
#       /meta
#       /profiles
#       /packages
#       /kernels
#   
#   
#   



SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

echo "############################### [ SNAPSHOTS ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/snapshots.mirrors rsync)"
echo -e "SYNCING w/ $URL \e[25,42m[SNAPSHOTS]\e[0m";sleep 1
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group ${URL} /var/lib/portage/ | tee /var/log/esync.log

echo "############################### [ RELEASES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors rsync only-sync)"
echo -e "SYNCING w/ $URL \e[25,42m[RELEASES]\e[0m";sleep 1
if [[ ! -d /var/lib/portage/releases ]]; then mkdir -p /var/lib/portage/releases; fi
rsync -avI --links --info=progress2 --timeout=300 --no-perms --ignore-times --ignore-existing --no-owner --no-group ${URL}${ARCH} /var/lib/portage/releases | tee /var/log/esync.log

echo "############################### [ DISTFILES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/distfiles.mirrors rsync)"
echo -e "SYNCING w/ $URL \e[25,42m[DISTFILES]\e[0m";sleep 1
rsync -avI --info=progress2 --timeout=300 --ignore-existing --ignore-times --no-perms --no-owner --no-group ${URL} /var/lib/portage/ | tee /var/log/esync.log

echo "updating mlocate-db"
/usr/bin/updatedb
/usr/bin/eix-update

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
hostip="$(/bin/ip --brief address show dev $hostip | /usr/bin/awk '{print $3}')"

# IMPORT meta-profile-package-patch data in to git repo, for tracking config changes (single user)
# in the future, a multi-user mode approach will be required to handle multiple systems/users/packages/profiles

pkgHOST="$(scanConfig ${SCRIPT_DIR}/config/host.cfg pkgserver host)"

mget rsync://${pkgHOST}/gentoo/meta/*			${SCRIPT_DIR}/meta/
mget rsync://${pkgHOST}/gentoo/profiles/*		${SCRIPT_DIR}/profiles/
mget rsync://${pkgHOST}/gentoo/packages/*		${SCRIPT_DIR}/packages/

# HAVE TO USE TAR/SSH because the rsync server can have issues with the permissions 
# OR USE UID = root GID = root in the rsyncd.conf on the pkgserver
# CHANGE PATCHFILES in to a tarchive, gitignore the archive, but in a directory place a readme w/ the spec.

mkdir -p /tmp/patchfiles_hold
mget ssh://root@${pkgHOST}:/var/lib/portage/patchfiles/	    /tmp/patchfiles_hold
mget rsync:///tmp/patchfiles_hold ${SCRIPT_DIR}/patchfiles


owner="$(stat -c '%U' ${SCRIPT_DIR})"
group="$(stat -c '%G' ${SCRIPT_DIR})"

chown ${owner}:${group} ${SCRIPT_DIR}/meta -R			1>/dev/null
chown ${owner}:${group} ${SCRIPT_DIR}/profiles -R		1>/dev/null
chown ${owner}:${group} ${SCRIPT_DIR}/packages -R		1>/dev/null

# sync repo from git source

repoServer="https://gitweb.gentoo.org/repo/gentoo.git/"

# type of meta data to crunch - GLSA / REPO / NEWS / DTD / ...

# MANUAL BUILD OF REPO

repo="/var/lib/portage/repos/gentoo"

if [[ ! -d ${repo} ]]; then git -C ${repo%/*} clone ${repoServer}; fi

git -C ${repo} fetch --all
git -C ${repo} pull

egencache --jobs $(nproc) --update --repo ${repo##*/} --write-timestamp --update-pkg-desc-index --update-use-local-desc


# SYNC FROM GIT REPO (SYNC-GENTOO)
