#!/bin/bash

/sbin/rc-service rsyncd stop
/sbin/rc-service lighttpd stop
/bin/sync
/var/lib/portage/sync-distfiles.sh
/var/lib/portage/sync-snapshots.sh
/var/lib/portage/sync-releases.sh

#/bin/echo "$(date)" >> /root/last_update.txt

/usr/bin/emerge --sync --verbose --ask=n
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
