#!/bin/bash

# ARGS: $SOURCE		$DESTINATION

#source="$1"
#destination="$2"

/sbin/rc-service rsyncd stop
/sbin/rc-service lighttpd stop
/bin/sync

#/var/lib/portage/sync-repos.sh
URL=./mirror.sh ../config/repos.mirrors * 
rsync -aP --info=progress2 $URL /var/lib/portage/repos/gentoo

#/var/lib/portage/sync-snapshots.sh
URL=./mirror.sh ../config/snapshots.mirrors *
rsync -aP --info=progress2 $URL /var/lib/portage/snapshots

#/var/lib/portage/sync-releases.sh
URL=./mirror.sh ../config/releases.mirrors *
rsync -aP --info=progress2 $URL /var/lib/portage/releases

#/var/lib/portage/sync-distfiles.sh
URL=./mirror.sh ../config/distfiles.mirrors *
rsync -aP --info=progress2 $URL /var/lib/portage/distfiles

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
/usr/bin/sleep 120
/bin/sync

/sbin/rc-service rsyncd start
/sbin/rc-service lighttpd start
