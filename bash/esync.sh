#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/include.sh

#ARCH="riscv/"
#ARCH="ppc/"
#ARCH="amd64/"
ARCH=""             # all archetectures

/sbin/rc-service rsyncd stop
/sbin/rc-service lighttpd stop
/bin/sync

echo "################################# [ REPOS ] #####################################"
URL="rsync://rsync.us.gentoo.org/gentoo-portage/"
echo -e "SYNCING w/ ***$URL*** [REPOS]"

# overcome sticky unverified download quarantine issue which occassionally props up (rsync)
unverified="none"
testCase="$(emerge --info | grep 'location:' | awk '{print $2}')/.tmp-unverified-download-quarantine"
while [[ -n ${unverified} ]]
do
    emerge --sync | tee /var/log/esync.log
    sleep 1
    sync
    if [[ -d  "${testCase}" ]];then unverified=""; fi
done

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

/bin/sed -i "s|   HOST:.*|   HOST: ${hostip}|" /etc/rsync/rsyncd.motd
/bin/sed -i "s|   DATE:.*|   DATE: $(date)|" /etc/rsync/rsyncd.motd

sleep 5

/bin/sync

/sbin/rc-service rsyncd start
/sbin/rc-service lighttpd start