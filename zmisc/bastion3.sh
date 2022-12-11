#!/bin/bash

#/sbin/dhcpcd -1

# REQUIRES NETWORK DHCP COMPLETE ...

#
#   BASTION {
#
#               METAL (w/ VM's) { 10.0.0.1 ; 10.1.0.1 ; 10.2.0.1 ...}
#               DOM-0 (@10.0.0.1) (w / containers : 10.1.0.2,3,4,5,6,...)
#               DOM-X (@10.X.0.1) (container 10.1.0.2)
#
#           }
#
#   DOMX(a)         DOMX(b)         DOMX(c)
#   hypokrites.me   hypokrites.io   hypokrites.me
#
#   DOMX(a & c) can be linked via vpn, and isolated to 10.2.X.Y
#   DOM0 will provide DHCP and DNS as well as other DOM Services
#   DOMX.root = 10.X.0.1 (localized DHCP/DNS/...) , per domain, or just use DOM0
#   containers or droplets, in the cloud can be attached to DOMX's , but for now cannot serve as domain roots
#   each VPN network, or DOMX_network is 192.168.0.1-> 192.168.255.255
#   DOM-0 can have 253 networks
#   DOM-X can have 65000 peers  DOM-0 resides on 10.X.X.X network, DOM-X subsists on 192.168.X.X network
#   DOM-Y is on the local entity, and is  limited to 172.16.0.0 -> 172.31.255.255 or a million hosts
#   DOM-Z { code / coplanar }
#
#   
#   
#   
#   
#





IPT="/sbin/iptables"
SYSCTL="/usr/sbin/sysctl"

LOOPBACK="lo"
LOOP_ADDR="$(ifconfig $LOOPBACK | grep 'inet ' | awk '{print $2}')"

#EXT_INTER ... THE WAN INTERFACE / EITHER PUBLIC OR PASSTHRU TO FW VM
EXT_INTER="$(route -n | grep '^0.0.0.0' | awk '{print $8}')"

#while [[ -z $EXT_INTER ]]
#do
#	EXT_INTER="$(route -n | grep '^0.0.0.0' | awk '{print $8}')"
#	sleep 1;
#	echo -n '.'
#done


EXT_ADDR="$(ifconfig $EXT_INTER | grep 'inet ' | awk '{print $2}')"
EXT_MASK="$(ifconfig $EXT_INTER | grep 'netmask ' | awk '{print $4}')"
EXT_NETWORK="$(ipcalc $EXT_ADDR/$EXT_MASK | grep 'Network' | awk '{print $2}')"

#INT_INTER ... THE LAN INTERFACE / PUBLIC, BRIDGE INTERFACE, TIED TO A VM-FW OR FW-FORWARD
INT_INTER="virbr0"




echo "EXT_NETWORK = $EXT_NETWORK"

#EXT_NTP1="clock3.redhat.com"
#EXT_NTP2="ntp.public.otago.ac.nz"

#########################################
#INT_INTER="enp8s0f0"
#INT_ADDR="10.0.0.1"
#INT_NET="10.0.0.0/8"

#INT_INTER="enp8s0"
#INT_ADDR="10.1.1.1"
#INT_NET="10.1.1.0/24"
#########################################

#IDROP="REJECT --reject-with icmp-port-unreach"
#UDROP="REJECT --reject-with icmp-port-unreach"
#TDROP="REJECT --reject-with tcp-rst"

IDROP="DROP"
UDROP="DROP"
TDROP="DROP"

#MODEM="192.168.100.1"

#$SYSCTL -w net/ipv4/conf/all/accept_redirects="0"
#$SYSCTL -w net/ipv4/conf/all/accept_source_route="0"
#$SYSCTL -w net/ipv4/conf/all/log_martians="1"
#$SYSCTL -w net/ipv4/conf/all/rp_filter="1"
#$SYSCTL -w net/ipv4/icmp_echo_ignore="1"
#$SYSCTL -w net/ipv4/icmp_echo_ignore_broadcasts="1"
#$SYSCTL -w net/ipv4/icmp_ignore_bogus_error_responses="1"
#$SYSCTL -w net/ipv4/ip_forward="0"
#$SYSCTL -w net/ipv4/tcp_syncookies="1"

#$IPT -X

# FLUSH ALL RULES !
$IPT-save | awk '/^[*]/ { print $1 } /^:[A-Z]+ [^-]/ {print $1 " ACCEPT" ; } /COMMIT/ { print $0; }' | iptables-restore

# detect invalid packets / rpfilter module - netfilter
$IPT -A PREROUTING -t raw -m rpfilter --invert -j DROP
#ip6tables -A PREROUTING -t raw -m rpfilter --invert -j DROP


#$IPT -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j $TDROP

# 7001 ?
#$IPT -I INPUT -p udp --dport 7001 -j DROP

#WAN

#LoopBack ... IPC MECHANISMS
#$IPT -A INPUT -i $LOOPBACK -j DROP
#$IPT -A FORWARD -i $LOOPBACK -j DROP
#$IPT -A OUTPUT -o $LOOPBACK -j DROP

# POSSIBLY COMPROMISED MODEM

#$IPT -A INPUT -i $EXT_INTER -s $MODEM -j DROP
#$IPT -A OUTPUT -o $EXT_INTER -d $MODEM -j DROP
#$IPT -A FORWARD -i $EXT_INTER -s $MODEM -j DROP
#$IPT -A FORWARD -i $EXT_INTER -d $MODEM -j DROP

#$IPT -N BAD_SOURCES

### TROUBLESHOOT ###########################################
# $IPT -A BAD_SOURCES -i $INT_INTER ! -s $INT_ADDR -j DROP #
# $IPT -A BAD_SOURCES -i $EXT_INTER ! -s $EXT_ADDR -j DROP #
############################################################

$IPT -N SRC_0
$IPT -A INPUT -i $EXT_INTER -s 0.0.0.0/8 -j SRC_0
$IPT -A SRC_0 -j $IDROP

#$IPT -N SAME_ADDY
#$IPT -A INPUT -j SAME_ADDY
#$IPT -A SAME_ADDY -i $INT_INTER -s $INT_ADDR -j $IDROP
#$IPT -A SAME_ADDY -i $EXT_INTER -s $EXT_ADDR -j $IDROP

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




#$IPT -A BAD_SOURCES -i $EXT_INTER -s 10.0.0.0/8 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 172.16.0.0/12 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 192.168.0.0/16 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 192.0.2.0/24 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 244.0.0.0/4 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 240.0.0.0/5 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 248.0.0.0/5 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 127.0.0.0/7 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 255.255.255.255/32 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -i $EXT_INTER -s 0.0.0.0/8 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -j $TDROP

#$IPT -A INPUT -i $EXT_INTER -s 10.0.0.0/8 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 172.16.0.0/12 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 192.168.0.0/16 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 192.0.2.0/24 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 244.0.0.0/4 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 240.0.0.0/5 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 248.0.0.0/5 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 127.0.0.0/7 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/32 -j BAD_SOURCES
#$IPT -A INPUT -i $EXT_INTER -s 0.0.0.0/8 -j BAD_SOURCES
#$IPT -A BAD_SOURCES -j $TDROP



#$IPT -A PREROUTING -i $EXT_INTER -s $MODEM -j DROP


#SAN (SECURE WIRED)
#LAN (WIFI ... UNSECURE WIRED)

$IPT -N FRAGS
$IPT -A INPUT -f -j FRAGS
$IPT -A FRAGS -j DROP

#$IPT -N DROP_ZERO
#$IPT -A INPUT --dport 0 -j DROP_ZERO
#$IPT -A OUTPUT --dport 0 -j DROP_ZERO
#$IPT -A FORWARD --dport 0 -j DROP_ZERO
#$IPT -A DROP_ZERO -j DROP


$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j $TDROP



############################# BLOCK NMAP

######################################################################################################

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

###########################

$IPT -N FORWARD_I_LOG
$IPT -A FORWARD -p all -i $INT_INTER -j FORWARD_I_LOG
#$IPT -I FORWARD_I_LOG -j LOG --log-prefix "IPT: FORWARD-INTERNAL: "
$IPT -I FORWARD_I_LOG -j ACCEPT


$IPT -N FORWARD_E_LOG
$IPT -A FORWARD -p all -i $EXT_INTER -j FORWARD_E_LOG
#$IPT -I FORWARD_I_LOG -j LOG --log-prefix "IPT: FORWARD-EXTERNAL: "
$IPT -I FORWARD_E_LOG -j DROP


#$IPT -N FORWARD_L_LOG
#$IPT -A FORWARD -p all -i $LOOPBACK -j FORWARD_L_LOG
#$IPT -I FORWARD_I_LOG -j LOG --log-prefix "IPT: FORWARD-LOOPBACK: "
#$IPT -I FORWARD_L_LOG -j DROP

$IPT -N DENY_ALL
$IPT -A INPUT -p all -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j DENY_ALL
#$IPT -I INPUT -i $EXT_INTER -m state --state ESTABLISHED,RELATED -j LOG --log-prefix "IPT: ACC ICMP - "
$IPT -I DENY_ALL -j DROP

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

#$IPT -A ICMP_INPUT -i $EXT_INTER -p icmp --icmp-type 3 -m state --state ESTABLISHED,RELATED -j ACCEPT
#$IPT -A ICMP_INPUT -i $EXT_INTER -p icmp --icmp-type 11 -m state --state ESTABLISHED,RELATED -j ACCEPT




#$IPT -N SRC_172
#$IPT -A INPUT -i $EXT_INTER -s 172.16.0.0/12 -j SRC_172
##$IPT -A SRC_172 -i $EXT_INTER -j LOG --log-prefix "IPT: (BAD SRC): "
#$IPT -A SRC_172 -j $IDROP

#$IPT -N SRC_10
#$IPT -A INPUT -i $EXT_INTER -s 10.0.0.0/8 -j SRC_10
#$IPT -A SRC_10 -j $IDROP

#$IPT -N SRC_192_0
#$IPT -A INPUT -i $EXT_INTER -s 192.0.2.0/24 -j SRC_192_0
#$IPT -A SRC_192_0 -j $IDROP

#$IPT -N SRC_192_168
#$IPT -A INPUT -i $EXT_INTER -s 192.168.0.0/16 -j SRC_192_168
#$IPT -A SRC_192_168 -j $IDROP

#$IPT -N SRC_240
#$IPT -A INPUT -i $EXT_INTER -s 192.168.0.0/16 -j SRC_240
#$IPT -A SRC_240 -j $IDROP

#$IPT -N SRC_244
#$IPT -A INPUT -i $EXT_INTER -s 244.0.0.0/4 -j SRC_244
#$IPT -A SRC_244 -j $IDROP

#$IPT -N SRC_248
#$IPT -A INPUT -i $EXT_INTER -s 248.0.0.0/5 -j SRC_248
#$IPT -A SRC_248 -j $IDROP

#$IPT -N SRC_127
#$IPT -A INPUT -i $EXT_INTER -s 127.0.0.0/7 -j SRC_127
#$IPT -A SRC_127 -j $IDROP

#$IPT -N SRC_255
#$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/32 -j SRC_255
##$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/24 -j SRC_255
##$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/16 -j SRC_255
##$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/8 -j SRC_255
##$IPT -A INPUT -i $EXT_INTER -s 255.255.255.255/0 -j SRC_255
#$IPT -A SRC_255 -j $IDROP


#$IPT -N BAD_FLAGS
#$IPT -A INPUT -i $EXT_INTER -j BAD_FLAGS
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN SYN,FIN -j LOG --log-prefix "IPT: BAD SF FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN SYN,FIN -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "IPT: BAD SR FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,RST SYN,RST -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j LOG --log-prefix "IPT: BAD SFP FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,PSH SYN,FIN,PSH -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j LOG --log-prefix "IPT: BAD SFR FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST SYN,FIN,RST -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j LOG --log-prefix "IPT: BAD SFRP FLAG "
#$IPT -A BAD_FLAGS  -p tcp --tcp-flags SYN,FIN,RST,PSH SYN,FIN,RST,PSH -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags FIN FIN -j LOG --log-prefix "IPT: BAD F FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags FIN FIN -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "IPT: BAD NULL FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL NONE -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "IPT: BAD ALL FLAG "
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL ALL -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL FIN,URG,PSH -j LOG --log-prefix "IPT: NMAP X-Mas Flag"
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL FIN,URG,PSH -j $TDROP
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "IPT: Merry X-Mas Flag"
#$IPT -A BAD_FLAGS -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j $TDROP

#$IPT -A INPUT -i $EXT_INTER -p tcp --syn -m limit --limit 5/second -j ACCEPT

$IPT -A INPUT -j LOG --log-prefix "IPT: --INPUT "


$IPT -N DROP_ICMP
$IPT -A INPUT -p icmp -i $EXT_INTER --j DROP_ICMP
$IPT -A DROP_ICMP -j LOG --log-prefix "IPT: DROP ICMP - "
$IPT -A DROP_ICMP -j $IDROP

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

###############################################$IPT -A INPUT -i $EXT_INTER -j $TDROP

#### SMTP ALLOW
####$IPT -A INPUT -i $EXT_INTER -p tcp --dport smtp -m state --state NEW,ESTABLISHED -j ACCEPT
####$IPT -A OUTPUT -o $EXT_INTER -p tcp --sport smtp -m state --state NEW,ESTABLISHED -j ACCEPT

# LAN SMTP ALLOW
####$IPT -A INPUT -i $EXT_INTER -p tcp -s $INT_SMTP --dport smtp -m state --state NEW,ESTABLISHED -j ACCEPT
####$IPT -A OUTPUT -o $EXT_INTER -p tcp -d $INT_SMTP --sport smtp -m state --state NEW,ESTABLISHED -j ACCEPT

#Internet DNS Rules
#$IPT -A INPUT -i $EXT_INTER -p udp --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i $EXT_INTER -p tcp --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT

#$IPT -A OUTPUT -o $EXT_INTER -p udp --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $EXT_INTER -p tcp --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT

# Internal Network Incoming DNS Rules
#$IPT -A INPUT -i $INT_INTER -p udp -s $INT_DNS1 --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i $INT_INTER -p tcp -s $INT_DNS1 --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i $INT_INTER -p udp -s $INT_DNS2 --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i $INT_INTER -p tcp -s $INT_DNS2 --dport domain -m state --state NEW,ESTABLISHED -j ACCEPT

# Internal Network Outgoing DNS Rules
#$IPT -A OUTPUT -o $INT_INTER -p udp -s $INT_DNS1 --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $INT_INTER -p tcp -s $INT_DNS1 --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $INT_INTER -p udp -s $INT_DNS2 --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $INT_INTER -p tcp -s $INT_DNS2 --sport domain -m state --state NEW,ESTABLISHED -j ACCEPT

#Internet NTP Rules
#$IPT -A INPUT -i $EXT_INTER -p udp -s $EXT_NTP1 --dport ntp -m state --state ESTABLISHED -j ACCEPT
#$IPT -A INPUT -i $EXT_INTER -p udp -s $EXT_NTP2 --dport ntp -m state --state ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $EXT_INTER -p udp -s $EXT_NTP1 --sport ntp -m state --state ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $EXT_INTER -p udp -s $EXT_NTP2 --sport ntp -m state --state ESTABLISHED -j ACCEPT

#Internal Network SSH Rules
#$IPT -A INPUT -i $INT_INTER -p tcp -s $INT_NET --dport ssh -m state --state NEW,ESTABLISHED -j ACCEPT
#$IPT -A OUTPUT -o $INT_INTER -p tcp -s $INT_NET --sport ssh -m state --state NEW,ESTABLISHED -j ACCEPT

#Outbound, connected back in
#$IPT -I OUTPUT -p tcp -o $EXT_INTER -s $EXT_ADDR -d 0.0.0.0/8 -j ACCEPT
#$IPT -I OUTPUT -p udp -o $EXT_INTER -s $EXT_ADDR -d 0.0.0.0/8 -j ACCEPT
#$IPT -I OUTPUT -p icmp -o $EXT_INTER -s $EXT_ADDR -d 0.0.0.0/8 -j ACCEPT
#$IPT -I OUTPUT -p all -o $EXT_INTER -s $EXT_ADDR -d 0.0.0.0/8 -j ACCEPT



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


########################################################

#$IPT -A OUTPUT -p icmp -o $EXT_INTER -s $EXT_ADDR -j LOG --log-prefix "IPT: icmp ? "
#$IPT -A OUTPUT -p icmp -o $EXT_INTER -j DROP

########################################################

#$IPT -A OUTPUT -p icmp -o $LOOPBACK -j DROP

#$IPT -A OUTPUT -p icmp -s $EXT_ADDR -j DROP

#$IPT -A OUTPUT -p icmp -d 0.0.0.0/8 -j DROP

#$IPT -A OUTPUT -p icmp -j DROP

#$IPT -N ICMP_OUTPUT
#$IPT -A OUTPUT -p icmp -j ICMP_OUTPUT
#$IPT -A ICMP_OUTPUT -o $EXT_INTER -p icmp --icmp-type 8 -m state --state NEW -j ACCEPT
#$IPT -A ICMP_OUTPUT -o $EXT_INTER -p icmp -j LOG --log-prefix "IPT: ICMP_OUTPUT: "
#$IPT -A ICMP_OUTPUT -o $EXT_INTER -p icmp -j $IDROP



# FORWARD TO  LOCAL NET
$IPT -A FORWARD -i $INT_INTER -j ACCEPT
$IPT -A FORWARD -o $INT_INTER -j ACCEPT

#FORWARD ACROSS INTERFACES ? -- NO

$IPT -t nat -A POSTROUTING -o $EXT_INTER -j MASQUERADE


################################################################## LAN ############################################

############### WHITE LIST LAN TRAFFIC ON SECURE NETWORK ##################################



#$IPT -N SRC_0_LAN
#$IPT -A INPUT -i $INT_INTER -s 0.0.0.0/8 -j SRC_0_LAN
#$IPT -A OUTPUT -o $INT_INTER -s 0.0.0.0/8 -j SRC_0_LAN
#$IPT -A SRC_0_LAN -j DROP

# SSH

#$IPT -N LAN_SSH
#$IPT -A INPUT -p tcp -i $INT_INTER -s $INT_NET -d $INT_ADDR --dport ssh -j LAN_SSH
#$IPT -A INPUT -p tcp -i $INT_INTER -s $INT_NET -d $INT_ADDR --sport ssh -j LAN_SSH
#$IPT -A OUTPUT -p tcp -o $INT_INTER -s $INT_ADDR -d $INT_NET --sport ssh  -j LAN_SSH
#$IPT -I LAN_SSH -j ACCEPT

# ICMP

#$IPT -N LAN_ICMP_IN
#$IPT -A INPUT -p icmp -i $INT_INTER -j LAN_ICMP_IN
#$IPT -A LAN_ICMP_IN -j LOG --log-prefix "IPT: LAN-ICMP-IN: "
#$IPT -I LAN_ICMP_IN -j ACCEPT

#$IPT -N LAN_ICMP_OUT
#$IPT -A OUTPUT -p icmp -o $INT_INTER -j LAN_ICMP_OUT
#$IPT -A LAN_ICMP_OUT -p icmp -o $INT_INTER -j LOG --log-prefix "IPT: LAN-ICMP-OUT: "
#$IPT -I LAN_ICMP_OUT -j ACCEPT

# NFS
#$IPT -N LAN_NFS

### EVENTUALLY PROVISION FOR VPN ONLY, SERVICES ENCAPSULATED #############################

#$IPT -N LAN_VPN

# MERCURY
#$IPT -N MERCURY_WG
# EARTH
#$IPT -N EARTH_WG
# MARS
#$IPT -N MARS_WG




############### WHITE LIST WIFI TRAFFIC ON ROUTER ##########################################



############### LOCAL HOST #################################################################

#$IPT -N LOCAL_ICMPZ
#$IPT -A INPUT -p icmp -i $LOOPBACK -s $LOOP_ADDR -d $LOOP_ADDR -j LOCAL_ICMPZ
#$IPT -A OUTOUT -p icmp -o $LOOPBACK -s $LOOP_ADDR -d $LOOP_ADDR -j LOCAL_ICMPZ
#$IPT -A LOCAL_ICMPZ -j ACCEPT



################################################################### NOT CAUGHT ... LOG ##############################



