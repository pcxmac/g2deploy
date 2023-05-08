#!/bin/bash

#/sbin/dhcpcd -1

# REQUIRES NETWORK DHCP COMPLETE ...

# sets up IP space, wg connections, and services... for now. 

IPT="/sbin/iptables"
SYSCTL="/usr/sbin/sysctl"

$SYSCTL -w net.ipv4.ip_forward=1

LOOPBACK="lo"
LOOP_ADDR="$(ifconfig $LOOPBACK | grep 'inet ' | awk '{print $2}')"

EXT_INTER="$(route -n | grep '^0.0.0.0' | head -n 1 | awk '{print $8}')"
echo "EXT_INTER = $EXT_INTER"
EXT_ADDR="$(ifconfig $EXT_INTER | grep 'inet ' | awk '{print $2}')"
echo "EXT_ADDR = $EXT_ADDR"
EXT_MASK="$(ifconfig $EXT_INTER | grep 'netmask ' | awk '{print $4}')"
echo "EXT_MASK = $EXT_MASK"
EXT_NETWORK="$(ipcalc $EXT_ADDR/$EXT_MASK | grep 'Network' | awk '{print $2}')"
echo "EXT_NETWORK = $EXT_NETWORK"

# DOMX SPACE	SOFTNET	.. DEFINED BY LXD (<<) or QEMU
#V_INTER="virbr1"
#INTERFACE=$V_INTER
#V_ADDR="$(ifconfig ${INTERFACE} | grep 'inet ' | awk '{print $2}')"
    #V_MASK="$(ifconfig ${INTERFACE} | grep 'netmask ' | awk '{print $4}')"
#V_NETWORK="$(ipcalc $V_ADDR/$EXT_MASK | grep 'Network' | awk '{print $2}')"
#echo "${V_INTER} / address : ${V_ADDR} :: mask : ${V_MASK} :: network : ${V_NETWORK}"

# DOM0 SPACE	METALNET .. DEFINED BY QEMU
M_INTER="lo"
INTERFACE=$M_INTER
M_ADDR="$(ifconfig ${INTERFACE} | grep 'inet ' | awk '{print $2}')"
M_MASK="$(ifconfig ${INTERFACE} | grep 'netmask ' | awk '{print $4}')"
M_NETWORK="$(ipcalc $M_ADDR/$EXT_MASK | grep 'Network' | awk '{print $2}')"
echo "${M_INTER} / address : ${M_ADDR} :: mask : ${M_MASK} :: network : ${M_NETWORK}"

echo "EXT_NETWORK = $EXT_NETWORK"

#############

sed -i "/pkg.hypokrites.me$/c$M_ADDR\tpkg.hypokrites.me" /etc/hosts
sed -i "/build.hypokrites.me$/c$M_ADDR\tbuild.hypokrites.me" /etc/hosts
# doesnt support other options, will need to --add the option function-- to this
sed -i "/RSYNC_OPTS/c RSYNC_OPTS=\"--address=$M_ADDR\"" /etc/conf.d/rsyncd
sed -i "/^server.bind/c server.bind = \"$M_ADDR\"" /etc/lighttpd/lighttpd.conf
sed -i "0,/listen_address/c listen_address=$M_ADDR" /etc/vsftpd.conf
sed -i "0,/ListenAddress/c ListenAddress $M_ADDR" /etc/ssh/sshd_config

rc-service lighttpd restart
rc-service sshd restart
rc-service vsftpd restart
rc-service rsyncd restart

###############3

IDROP="DROP"
UDROP="DROP"
TDROP="DROP"

#MODEM="192.168.100.1"

# FLUSH ALL RULES !
$IPT-save | awk '/^[*]/ { print $1 } /^:[A-Z]+ [^-]/ {print $1 " ACCEPT" ; } /COMMIT/ { print $0; }' | iptables-restore

# detect invalid packets / rpfilter module - netfilter
$IPT -A PREROUTING -t raw -m rpfilter --invert -j DROP

#$IPT -N SRC_0
#$IPT -A INPUT -i $EXT_INTER -s 0.0.0.0/8 -j SRC_0
#$IPT -A SRC_0 -j $IDROP

#$IPT -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j LOG --log-prefix "IPT: BAD SF FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags SYN,FIN SYN,FIN -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "IPT: BAD SR FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags SYN,RST SYN,RST -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j LOG --log-prefix "IPT: BAD SFP FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j LOG --log-prefix "IPT: BAD SFR FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j LOG --log-prefix "IPT: BAD SFRP FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j $TDROP
$IPT -A INPUT -p tcp --tcp-flags FIN FIN -j LOG --log-prefix "IPT: BAD F FLAG !!!! :: "

$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags FIN FIN -s www.gentoo.org -j ACCEPT

$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags FIN FIN -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "IPT: BAD NULL FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags ALL NONE -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "IPT: BAD ALL FLAG "
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags ALL ALL -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j LOG --log-prefix "IPT: NMAP X-Mas Flag"
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags ALL FIN,URG,PSH -j $TDROP
#$IPT -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "IPT: Merry X-Mas Flag"
$IPT -A INPUT -i $EXT_INTER -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j $TDROP

$IPT -N INV_IN
$IPT -A INPUT -i $EXT_INTER -s 0.0.0.0/8 -j INV_IN
#$IPT -A INVALID -m conntrack --ctstate INV_IN -j LOG --log-prefix "IPT: (conntrack) INV_STATE"
$IPT -A INV_IN -m conntrack --ctstate INVALID -j $IDROP
#$IPT -A INVALID -m state --state INV_IN -j LOG --log-prefix "IPT: (UDP) INV_STATE"
$IPT -A INV_IN -m state --state INVALID -j $IDROP

#$IPT -A INVALID -m state --state -p tcp INVALID -j LOG --log-prefix "IPT: (TCP) INV_STATE"
#$IPT -A INVALID -m state --state INVALID -j $TDROP

$IPT -N INV_OUT
$IPT -A OUTPUT -o $EXT_INTER -d 0.0.0.0/8 -j INV_OUT
#$IPT -A INV_OUT -m conntrack --ctstate INV_OUT -j LOG --log-prefix "IPT: (conntrack) INV_STATE"
$IPT -A INV_OUT -m conntrack --ctstate INVALID -j $IDROP
#$IPT -A INV_OUT -m state --state INV_OUT -j LOG --log-prefix "IPT: (UDP) INV_STATE"
$IPT -A INV_OUT -m state --state INVALID -j $IDROP

$IPT -N INV_FOR
$IPT -A FORWARD -i $EXT_INTER -d 0.0.0.0/8 -j INV_FOR
#$IPT -A INV_FOR -m conntrack --ctstate INV_FOR -j LOG --log-prefix "IPT: (conntrack) INV_STATE"
$IPT -A INV_FOR -m conntrack --ctstate INVALID -j $IDROP
#$IPT -A INV_FOR -m state --state INV_FOR -j LOG --log-prefix "IPT: (UDP) INV_STATE"
$IPT -A INV_FOR -m state --state INVALID -j $IDROP

$IPT -N FRAGS
$IPT -A INPUT -f -j FRAGS
$IPT -A FRAGS -j DROP

$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j $TDROP

$IPT -N ACCEPT_TCP
$IPT -A INPUT -p tcp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j ACCEPT_TCP
$IPT -I ACCEPT_TCP -j LOG --log-prefix "IPT: ACC TCP - "
$IPT -I ACCEPT_TCP -j ACCEPT

$IPT -N ACCEPT_UDP
$IPT -A INPUT -p udp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j ACCEPT_UDP
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC UDP - "
$IPT -I ACCEPT_UDP -j ACCEPT

$IPT -N ACCEPT_ICMP
$IPT -A INPUT -p icmp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j ACCEPT_ICMP
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC ICMP - "
$IPT -I ACCEPT_ICMP -j ACCEPT

$IPT -N FORWARD_TCP
$IPT -A FORWARD -p tcp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j FORWARD_TCP
#$IPT -I FORWARD_TCP -j LOG --log-prefix "IPT: ACC TCP - "
$IPT -I FORWARD_TCP -j ACCEPT

$IPT -N FORWARD_UDP
$IPT -A FORWARD -p udp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j FORWARD_UDP
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC UDP - "
$IPT -I FORWARD_UDP -j ACCEPT

$IPT -N FORWARD_ICMP
$IPT -A FORWARD -p icmp -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j FORWARD_ICMP
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC ICMP - "
$IPT -I FORWARD_ICMP -j ACCEPT


#$IPT -A FORWARD -i $V_INTER -o $EXT_INTER -j ACCEPT
#$IPT -A FORWARD -i $EXT_INTER -o $V_INTER -j ACCEPT
#$IPT -A FORWARD -i $EXT_INTER -o $V_INTER -m state --state ESTABLISHED,RELATED -j ACCEPT
#$IPT -t nat -A POSTROUTING -o $V_INTER -j MASQUERADE

$IPT -A FORWARD -i $M_INTER -o $EXT_INTER -j ACCEPT
$IPT -A FORWARD -i $EXT_INTER -o $M_INTER -j ACCEPT
#$IPT -A FORWARD -i $EXT_INTER -o $M_INTER -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -t nat -A POSTROUTING -o $M_INTER -j MASQUERADE

$IPT -t nat -A POSTROUTING -o $EXT_INTER -j MASQUERADE




###########################

#	$IPT -N FORWARD_I_LOG
#	$IPT -A FORWARD -p all -i $INT_INTER -j FORWARD_I_LOG
#	#$IPT -I FORWARD_I_LOG -j LOG --log-prefix "IPT: FORWARD-INTERNAL: "
#	$IPT -I FORWARD_I_LOG -j ACCEPT

$IPT -N FORWARD_E_LOG
$IPT -A FORWARD -p all -i $EXT_INTER -j FORWARD_E_LOG
#$IPT -I FORWARD_I_LOG -j LOG --log-prefix "IPT: FORWARD-EXTERNAL: "
$IPT -I FORWARD_E_LOG -j DROP

$IPT -N DENY_ALL
$IPT -A INPUT -p all -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j DENY_ALL
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC ICMP - "
$IPT -I DENY_ALL -j DROP

########################################################################################################

$IPT -A INPUT -i $EXT_INTER -s 192.168.0.0/16 -j ACCEPT
$IPT -A INPUT -i $EXT_INTER -s 10.0.0.0/8 -j ACCEPT

########################################################################################################

$IPT -N ICMP_ECHO_REPLY
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_ECHO_REPLY
$IPT -A ICMP_ECHO_REPLY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (0): "
$IPT -A ICMP_ECHO_REPLY -i $EXT_INTER -p icmp --icmp-type 0 -j $IDROP

$IPT -N ICMP_UNREACH
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_UNREACH
#$IPT -A ICMP_UNREACH -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (3): "
$IPT -A ICMP_UNREACH -i $EXT_INTER -p icmp --icmp-type 3 -j $IDROP

$IPT -N ICMP_REDIRECT
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_REDIRECT
#$IPT -A ICMP_REDIRECT -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (5): "
$IPT -A ICMP_REDIRECT -i $EXT_INTER -p icmp --icmp-type 5 -j $IDROP

$IPT -N ICMP_ECHO
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_ECHO
#$IPT -A ICMP_ECHO -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (8): "
$IPT -A ICMP_ECHO -i $EXT_INTER -p icmp --icmp-type 8 -j $IDROP

$IPT -N ICMP_ADVERT
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_ADVERT
#$IPT -A ICMP_ADVERT -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (9): "
$IPT -A ICMP_ADVERT -i $EXT_INTER -p icmp --icmp-type 9 -j $IDROP

$IPT -N ICMP_SELECT
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_SELECT
#$IPT -A ICMP_SELECT -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (10): "
$IPT -A ICMP_SELECT -i $EXT_INTER -p icmp --icmp-type 10 -j $IDROP

$IPT -N ICMP_EXCEED
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_EXCEED
#$IPT -A ICMP_EXCEED -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (11): "
$IPT -A ICMP_EXCEED -i $EXT_INTER -p icmp --icmp-type 11 -j $IDROP

$IPT -N ICMP_PARAM
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_PARAM
#$IPT -A ICMP_PARAM -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (12): "
$IPT -A ICMP_PARAM -i $EXT_INTER -p icmp --icmp-type 12 -j $IDROP

$IPT -N ICMP_STAMP
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_STAMP
#$IPT -A ICMP_STAMP -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (13): "
$IPT -A ICMP_STAMP -i $EXT_INTER -p icmp --icmp-type 13 -j $IDROP

$IPT -N ICMP_TREPLY
$IPT -A INPUT -i$EXT_INTER -p icmp -j ICMP_TREPLY
#$IPT -A ICMP_TREPLY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (14): "
$IPT -A ICMP_TREPLY -i $EXT_INTER -p icmp --icmp-type 14 -j $IDROP

$IPT -N ICMP_SECURITY
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_SECURITY
#$IPT -A ICMP_SECURITY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (19): "
$IPT -A ICMP_SECURITY -i $EXT_INTER -p icmp --icmp-type 19 -j $IDROP

$IPT -N ICMP_EXT_ECHO
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_EXT_ECHO
#$IPT -A ICMP_EXT_ECHO -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (42): "
$IPT -A ICMP_EXT_ECHO -i $EXT_INTER -p icmp --icmp-type 42 -j $IDROP

$IPT -N ICMP_EXT_REPLY
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_EXT_REPLY
#$IPT -A ICMP_EXT_REPLY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (43): "
$IPT -A ICMP_EXT_REPLY -i $EXT_INTER -p icmp --icmp-type 43 -j $IDROP

$IPT -N ICMP6_WHERE
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP6_WHERE
#$IPT -A ICMP_EXT_REPLY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (33): "
$IPT -A ICMP6_WHERE -i $EXT_INTER -p icmp --icmp-type 33 -j $IDROP

$IPT -N ICMP6_HERE
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP6_HERE
#$IPT -A ICMP_EXT_REPLY -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (34): "
$IPT -A ICMP6_HERE -i $EXT_INTER -p icmp --icmp-type 34 -j $IDROP

$IPT -N ICMP_IN_OTHER
$IPT -A INPUT -i $EXT_INTER -p icmp -j ICMP_IN_OTHER
#$IPT -A ICMP_IN_OTHER -i $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_INPUT (OTHER): "
$IPT -A ICMP_IN_OTHER -i $EXT_INTER -p icmp -j $IDROP


$IPT -A INPUT -j LOG --log-prefix "IPT: --INPUT "

$IPT -N DROP_ICMP
$IPT -A INPUT -p icmp -i $EXT_INTER --j DROP_ICMP
$IPT -A DROP_ICMP -j LOG --log-prefix "IPT: DROP ICMP - "
$IPT -A DROP_ICMP -j $IDROP

#$IPT -N ACCEPT_TCP
$IPT -A INPUT -p tcp -i $EXT_INTER --sport 873 -m conntrack --ctstate ESTABLISHED -j ACCEPT
#$IPT -A ACCEPT_TCP -p tcp -j ACCEPT

$IPT -N DROP_TCP
$IPT -A INPUT -p tcp -i $EXT_INTER --j DROP_TCP
$IPT -A DROP_TCP -p tcp -j LOG --log-prefix "IPT: DROP TCP - "
$IPT -A DROP_TCP -p tcp -j $TDROP

$IPT -N DROP_UDP
$IPT -A INPUT -p udp -i $EXT_INTER --j DROP_UDP
$IPT -A DROP_UDP -j LOG --log-prefix "IPT: DROP UDP - "
$IPT -A DROP_UDP -j $UDROP

$IPT -N DROP_INPUT
$IPT -A INPUT -p all -i $EXT_INTER --j DROP_INPUT
#$IPT -A DROP_INPUT -j LOG --log-prefix "IPT: DROP ALL - "
$IPT -A DROP_INPUT -j DROP

$IPT -A INPUT -i $EXT_INTER -s $EXT_NETWORK -j ACCEPT
$IPT -A INPUT -i $EXT_INTER ! -s $EXT_NETWORK -j LOG --log-prefix "IPT: INPUT DROPPED / "
$IPT -A INPUT -i $EXT_INTER -j $TDROP
$IPT -A INPUT -i $EXT_INTER -j $UDROP
$IPT -A INPUT -i $EXT_INTER -j $IDROP

#####################################################3

$IPT -N LOOP_TCP
$IPT -A OUTPUT -p icmp -o $LOOPBACK -s $LOOP_ADDR ! -d $LOOP_ADDR -j LOOP_TCP
$IPT -A LOOP_TCP -j $TDROP

$IPT -N LOOP_UDP
$IPT -A OUTPUT -p icmp -o $LOOPBACK -s $LOOP_ADDR ! -d $LOOP_ADDR -j LOOP_UDP
$IPT -A LOOP_UDP -j $UDROP

$IPT -N LOOP_ICMP
$IPT -A OUTPUT -p icmp -o $LOOPBACK -s $LOOP_ADDR ! -d $LOOP_ADDR -j LOOP_ICMP
$IPT -A LOOP_ICMP -j $IDROP

$IPT -N OUT_TCP
$IPT -A OUTPUT -p tcp -o $EXT_INTER -s $EXT_ADDR -j OUT_TCP
$IPT -A OUT_TCP -j ACCEPT

$IPT -N OUT_UDP
$IPT -A OUTPUT -p udp -o $EXT_INTER -s $EXT_ADDR -j OUT_UDP
$IPT -A OUT_UDP -j ACCEPT

##############################################################################

$IPT -N OUT_ICMP
$IPT -A OUTPUT -p icmp -o $EXT_INTER -s $EXT_ADDR -j OUT_ICMP
$IPT -A OUT_ICMP -j ACCEPT

##############################################################################

$IPT -N STOP_TCP
$IPT -A OUTPUT -p tcp -d 0.0.0.0/8 -j STOP_TCP
$IPT -A STOP_TCP -p tcp -j $TDROP

$IPT -N STOP_UDP
$IPT -A OUTPUT -p udp -d 0.0.0.0/8 -j STOP_UDP
$IPT -A STOP_UDP -j $UDROP

$IPT -N STOP_ICMP
$IPT -A OUTPUT -p icmp -d 0.0.0.0/8 -j STOP_ICMP
$IPT -A STOP_ICMP -j $IDROP

#$IPT -A OUTPUT -p icmp -s $EXT_ADDR -d $EXT_ADDR -j $IDROP

$IPT -A OUTPUT -p udp -o $LOOPBACK -j LOG --log-prefix "IPT: udp / lo - "
$IPT -A OUTPUT -p udp -o $LOOPBACK -j DROP

#$IPT -A OUTPUT -p tcp -j LOG --log-prefix "IPT: tcp ??? "
#$IPT -A OUTPUT -p tcp -j DROP
$IPT -A OUTPUT -p udp -j DROP

$IPT -A OUTPUT -j LOG --log-prefix "IPT: OUTPUT- "

# FORWARD TO  LOCAL NET

#FORWARD ACROSS INTERFACES ? -- NO

