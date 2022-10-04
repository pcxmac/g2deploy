#!/bin/bash

# ARGS: $SOURCE		$DESTINATION

#source="$1"
#destination="$2"

#SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/.."
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

echo $SCRIPT_DIR

/sbin/rc-service rsyncd stop
/sbin/rc-service lighttpd stop
/bin/sync

echo "${SCRIPT_DIR}"

URL="rsync://rsync.us.gentoo.org/gentoo-portage/"

echo "############################### [ REPOS ] ###################################"
#URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/ESYNC/repos.mirrors * )"
echo -e "SYNCING w/ ***$URL*** [REPOS]"
#rsync -avPI --info=progress2 --no-perms --ignore-existing --no-owner --no-group ${URL} /var/lib/portage/repos/gentoo
emerge --sync | tee /var/log/esync.log

echo "############################### [ SNAPSHOTS ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/ESYNC/snapshots.mirrors * )"
echo -e "SYNCING w/ $URL \e[25,42m[SNAPSHOTS]\e[0m";sleep 1
rsync -avPI --info=progress2 --timeout=300 --ignore-existing --no-perms --no-owner --no-group ${URL} /var/lib/portage/ | tee /var/log/esync.log

echo "############################### [ RELEASES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/ESYNC/releases.mirrors * )"
echo -e "SYNCING w/ $URL \e[25,42m[RELEASES]\e[0m";sleep 1

# destination URL is extended due to 'amd64' being the only requested arch for releases, perhaps select for, in this script later ie x32, amd64, arm,...
rsync -avPI --info=progress2 --timeout=300 --ignore-existing --no-perms --no-owner --no-group ${URL} /var/lib/portage/releases | tee /var/log/esync.log


echo "############################### [ DISTFILES ] ###################################"
URL="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/ESYNC/distfiles.mirrors * )"
echo -e "SYNCING w/ $URL \e[25,42m[DISTFILES]\e[0m";sleep 1
rsync -avPI --info=progress2 --timeout=300 --ignore-existing --no-perms --no-owner --no-group ${URL} /var/lib/portage/ | tee /var/log/esync.log

echo "updating mlocate-db"
/usr/bin/updatedb
/usr/bin/eix-update

hostip="$(/bin/route -n | /bin/grep "^0.0.0.0" | /usr/bin/awk '{print $8}')"
#echo "$hostip"
hostip="$(/bin/ip --brief address show dev $hostip | /usr/bin/awk '{print $3}')"
#echo "$hostip"

/bin/sed -i "s|   HOST:.*|   HOST: ${hostip}|" /etc/rsync/rsyncd.motd
/bin/sed -i "s|   DATE:.*|   DATE: $(date)|" /etc/rsync/rsyncd.motd

#/bin/echo "sleeping till ... $(date --date='+2 minutes')"
echo "sleeping..."
#/usr/bin/sleep 10
/bin/sync

/sbin/rc-service rsyncd start
/sbin/rc-service lighttpd start

